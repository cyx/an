require "net/http"
require "net/https"
require "uri"
require "scrivener"

class AN
  class << self
    attr_accessor :login_id
    attr_accessor :transaction_key
  end

  class ValueObject < Scrivener
    # This is an Authorize.net specific implementation detail,
    # basically all their field names are prefixed with an `x_`.
    def to_hash
      {}.tap do |ret|
        attributes.each do |att, val|
          ret["x_#{att}"] = val
        end
      end
    end
  end

  class CreditCard < ValueObject
    attr_accessor :card_num
    attr_accessor :card_code
    attr_accessor :exp_month
    attr_accessor :exp_year

    def validate
      assert_present(:card_num) &&
        assert(Luhn.check(card_num), [:card_num, :not_valid])

      assert_present(:card_code)

      assert_format(:exp_month, /\A\d{1,2}\z/) &&
        assert_format(:exp_year, /\A\d{4}\z/) &&
          assert(exp_in_future, [:exp_date, :not_valid])
    end

    # Convert to the expiry date expected by the API which is in MMYY.
    def exp_date
      y = "%.4i" % exp_year
      m = "%.2i" % exp_month

      "#{m}#{y[-2..-1]}"
    end

    # Because the expected parameters are significantly different
    # than what we have for free from `ValueObject`, it's much
    # simpler to just write our own `to_hash` here.
    def to_hash
      { "x_card_num" => card_num, "x_card_code" => card_code,
        "x_exp_date" => exp_date }
    end

  private
    def exp_in_future
      Time.new(exp_year, exp_month) > Time.now
    end
  end

  class Customer < ValueObject
    attr_accessor :first_name
    attr_accessor :last_name
    attr_accessor :address
    attr_accessor :state
    attr_accessor :zip
    attr_accessor :email

    def validate
      assert_present :first_name
      assert_present :last_name
    end
  end

  class Invoice < ValueObject
    attr_accessor :invoice_num
    attr_accessor :amount
    attr_accessor :description

    def amount=(amount)
      if amount.nil? || amount.empty?
        @amount = nil
      else
        @amount = "%.2f" % amount
      end
    end

    def validate
      assert_present(:invoice_num) && assert_length(:invoice_num, 1..20)
      assert_present(:amount)
      assert_present(:description)
    end
  end

  # Client idea taken from http://github.com/soveran/rel
  class Client
    attr :http
    attr :path

    def initialize(uri)
      @path = uri.path
      @http = Net::HTTP.new(uri.host, uri.port)
      @http.use_ssl = true if uri.scheme == "https"
    end

    def post(params)
      reply(http.post(path, params))
    end

    def reply(res)
      raise RuntimeError, res.inspect unless res.code == "200"

      res.body
    end

    def self.connect(url)
      new(URI.parse(url))
    end
  end

  class AIM
    DELIMITER = "<|>"

    DEFAULT_PARAMS = {
      "x_version"        => "3.1",
      "x_delim_data"     => "TRUE",
      "x_delim_char"     => DELIMITER,
      "x_relay_response" => "FALSE",
      "x_method"         => "CC"
    }.freeze

    TEST = "https://test.authorize.net/gateway/transact.dll"
    LIVE = "https://secure.authorize.net/gateway/transact.dll"

    RESPONSE_FIELDS = %w[code subcode reason_code reason_text
                         authorization_code avs_response trans_id
                         invoice_number description amount method
                         transaction_type customer_id first_name
                         last_name company address city state zip
                         country phone fax email
                         shipping_first_name shipping_last_name
                         shipping_company shipping_address shipping_city
                         shipping_state shipping_zip shipping_country
                         tax duty freight tax_exempt purchase_order_number
                         md5_hash card_code_response cavv_response
                         account_number card_type split_tender_id
                         requested_amount balance_on_card]

    def self.test
      new(TEST)
    end

    def self.live
      new(LIVE)
    end

    def initialize(url)
      @client = Client.connect(url)
      @params = DEFAULT_PARAMS.merge(
        "x_login" => AN.login_id,
        "x_tran_key" => AN.transaction_key
      )
    end

    def sale(customer, invoice, card)
      transact("AUTH_CAPTURE", customer, invoice, card)
    end

    def authorize(customer, invoice, card)
      transact("AUTH_ONLY", customer, invoice, card)
    end

    def capture(trans_id)
      transact("PRIOR_AUTH_CAPTURE", {
        "x_trans_id" => trans_id
      })
    end

    def refund(trans_id, card_num, amount)
      transact("CREDIT", {
        "x_trans_id" => trans_id,
        "x_card_num" => card_num,
        "x_amount" => amount
      })
    end

    def void(trans_id, split_tender_id = nil)
      transact("VOID", {
        "x_trans_id" => trans_id,
        "x_split_tender_id" => split_tender_id
      })
    end

  private
    def transact(type, *models)
      params = @params.merge("x_type" => type, "x_email_customer" => "TRUE")
      models.each { |model| params.merge!(model.to_hash) }

      response = Hash[RESPONSE_FIELDS.zip(post(params))]

      if response["code"] == "1"
        response
      else
        raise TransactionFailed.new(response), response["reason_text"]
      end
    end

    def post(params)
      @client.post(URI.encode_www_form(params)).split(DELIMITER)
    end
  end

  class TransactionFailed < StandardError
    attr :response

    def initialize(response)
      @response = response
    end
  end

  # @see http://en.wikipedia.org/wiki/Luhn_algorithm
  # @credit https://gist.github.com/1182499
  module Luhn
    RELATIVE_NUM = { '0' => 0, '1' => 2, '2' => 4, '3' => 6, '4' => 8,
                     '5' => 1, '6' => 3, '7' => 5, '8' => 7, '9' => 9 }

    def self.check(number)
      number = number.to_s.gsub(/\D/, "").reverse

      sum = 0

      number.split("").each_with_index do |n, i|
        sum += (i % 2 == 0) ? n.to_i : RELATIVE_NUM[n]
      end

      sum % 10 == 0
    end
  end
end
