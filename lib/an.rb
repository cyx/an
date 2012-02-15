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
    OK = "Ok"

    def initialize(xml)
      @data = XmlSimple.xml_in(xml, forcearray: false)
    end

    def [](key)
      @data[key]
    end

    def success?
      @data["messages"]["resultCode"] == OK
    end

    def to_hash
      @data
    end

    def profile_id
      @data["customerProfileId"]
    end

    def payment_profile_id
      @data["customerPaymentProfileId"]
    end

    def authorization
      response = @data["validationDirectResponse"] || @data["directResponse"]

      AuthorizationResponse.new(response) if response
    end
  end

  class AuthorizationResponse
    FIELDS = {
      1  => "responseCode",
      3  => "messageCode",
      4  => "messageDescription",
      5  => "authCode",
      6  => "avsResultCode",
      7  => "transId",
      38 => "transHash",
      39 => "cvvResultCode",
      40 => "cavvResultCode",
      51 => "accountNumber",
      52 => "accountType"
    }

    def initialize(data, delimiter = ",")
      @list = data.split(delimiter)
      @data = {}

      FIELDS.each do |index, field|
        # The FIELDS hash is using a 1-based index in order
        # to match the ordering number in the AIM documentation.
        @data[field] = @list[index - 1]
      end
    end

    def to_hash
      @data
    end

    def [](key)
      @data[key]
    end

    def success?
      @data["responseCode"] == "1" && @data["messageCode"] == "1"
    end

    def transaction_id
      @data["transId"]
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
