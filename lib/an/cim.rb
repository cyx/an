require "mote"
require "xmlsimple"

module AN
  class CIM
    TEST = "https://apitest.authorize.net/xml/v1/request.api"
    LIVE = "https://api.authorize.net/xml/v1/request.api"
    
    include Mote::Helpers

    def self.test
      new(TEST)
    end

    def self.live
      new(LIVE)
    end

    def initialize(url)
      @client = Client.connect(url)
      @params = { login: AN.login_id, tran_key: AN.transaction_key }
    end

    def create_customer(params)
      CreateCustomerResponse.new(post("create-profile", params))
    end

    def create_payment_profile(params)
      CreatePaymentProfileResponse.new(post("create-payment-profile", params))
    end
  
    def create_transaction(params)
      CreateTransactionResponse.new(post("create-transaction", params))
    end

  private
    def post(name, params)
      xml_response = @client.post(
        mote(cached_path(name), @params.merge(params)),
        "Content-Type" => "text/xml"
      )

      XmlSimple.xml_in(xml_response, forcearray: false, keeproot: false)
    end

    def cached_path(name)
      Thread.current[:AN] ||= {}
      Thread.current[:AN][name] ||= path(name)
    end

    def path(name)
      File.expand_path("../../templates/#{name}.xml", File.dirname(__FILE__))
    end
  
    class Response
      attr :response

      def initialize(response)
        @response = response
      end

      def success?
        response["messages"]["resultCode"] == "Ok" &&
          response["messages"]["message"]["code"] == "I00001"
      end
    end

    class CreateCustomerResponse < Response
      attr :ref_id
      attr :profile_id

      def initialize(response)
        super

        @profile_id = response["customerProfileId"]
        @ref_id = response["refId"]
      end
    end

    class CreatePaymentProfileResponse < Response
      attr :payment_profile_id
      attr :payment_response

      def initialize(response)
        super

        @payment_profile_id = response["customerPaymentProfileId"]
        @payment_response = PaymentResponse.new(response["validationDirectResponse"])
      end
    end

    class CreateTransactionResponse < Response
      attr :payment_response

      def initialize(response)
        super        

        @payment_response = PaymentResponse.new(response["directResponse"])
      end
    end
  end
end
