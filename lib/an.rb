require "mote"
require "net/http"
require "net/https"
require "uri"
require "xmlsimple"

class AN
  # In production systems, you can simply set
  #
  # AUTHORIZE_NET_URL=https://login:key@api.authorize.net/xml/v1/request.api
  #
  # in the appropriate location (e.g. /etc/profile.d, ~/.bashrc, or 
  # whatever you're most comfortable with.
  #
  # The TEST URL is https://apikey.authorize.net/xml/v1/request.api
  def self.connect(url = ENV["AUTHORIZE_NET_URL"])
    new(URI(url))
  end
  
  TEMPLATES = File.expand_path("../templates", File.dirname(__FILE__))

  include Mote::Helpers

  attr :url
  attr :auth
  attr :client
 
  def initialize(uri)
    @auth   = { login: uri.user, transaction_key: uri.password }
    @client = Client.new(uri)
  end

  def transact(params)
    call("createTransactionRequest", params)
  end

  def create_profile(params)
    call("createCustomerProfileRequest", params)
  end

  def create_payment_profile(params)
    call("createCustomerPaymentProfileRequest", params)
  end
  
  def create_profile_transaction(params)
    call("createCustomerProfileTransactionRequest", params)
  end

private 
  def call(api_call, params)
    Response.new(post(payload(api_call, params)))
  end
  
  def post(xml)
    client.post(xml, "Content-Type" => "text/xml")
  end

  def payload(api_call, params)
    mote(File.join(TEMPLATES, "%s.mote" % api_call), params.merge(auth))
  end
  
  class Response
    attr :data
  
    OK = "Ok"

    def initialize(xml)
      @data = XmlSimple.xml_in(xml, forcearray: false)      
    end

    def success?
      data["messages"]["resultCode"] == OK
    end

    def transaction_id
      data["transactionResponse"]["transId"]      
    end

    def reference_id
      data["refId"]
    end

    def profile_id
      data["customerProfileId"]      
    end

    def payment_profile_id
      data["customerPaymentProfileId"]
    end

    def validation_response
      if resp = data["validationDirectResponse"] || data["directResponse"]
        ValidationResponse.new(resp)
      end
    end
  end

  class ValidationResponse
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
                         _41 _42 _43 _44 _45 _46 _47 _48 _49 _50
                         account_number card_type split_tender_id
                         requested_amount balance_on_card].freeze

    attr :fields

    def initialize(data, delimiter = ",")
      @fields = Hash[RESPONSE_FIELDS.zip(data.split(delimiter))]
    end

    def success?
      fields["code"] == "1" && fields["reason_code"] == "1"
    end

    def transaction_id
      fields["trans_id"]
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

    def post(params, *args)
      reply(http.post(path, params, *args))
    end

    def reply(res)
      raise RuntimeError, res.inspect unless res.code == "200"

      res.body
    end

    def self.connect(url)
      new(URI.parse(url))
    end
  end

end

__END__

module AN
  require_relative "an/client"
  require_relative "an/model"
  require_relative "an/aim"
  require_relative "an/cim"

  class << self
    attr_accessor :login_id
    attr_accessor :transaction_key
  end

  class PaymentResponse
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

    attr :fields

    def initialize(data, delimiter = ",")
      @fields = Hash[RESPONSE_FIELDS.zip(data.split(delimiter))]
    end

    def success?
      fields["code"] == "1" && fields["reason_code"] == "1"
    end

    def code
      fields["code"]
    end

    def message
      fields["reason_text"]
    end

    def trans_id
      fields["trans_id"]
    end
  end
end
