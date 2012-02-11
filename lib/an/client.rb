require "net/http"
require "net/https"
require "uri"

module AN
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
