module AN
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
    # TODO: x_email_customer should be customizable
    def transact(type, *models)
      params = @params.merge("x_type" => type, "x_email_customer" => "TRUE")
      models.each { |model| params.merge!(model.to_hash) }

      response = PaymentResponse.new(post(params), DELIMITER)

      if response.success?
        response
      else
        raise TransactionFailed.new(response.fields), response.message
      end
    end

    def post(params)
      @client.post(URI.encode_www_form(params))
    end
  end

  class TransactionFailed < StandardError
    attr :response

    def initialize(response)
      @response = response
    end
  end
end
