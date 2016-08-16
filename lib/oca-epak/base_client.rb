module Oca
  class BaseClient
    attr_reader :client
    attr_accessor :username, :password

    BASE_WSDL_URL = "http://webservice.oca.com.ar".freeze
    FALSE_STRING = "false".freeze

    def initialize(username, password)
      @username = username
      @password = password
    end

    protected

    def parse_result(response, method)
      schema = parse_body(response, method)[:schema]
      payload = parse_body(response, method)[:diffgram]
      results_key, results_topic_keys = get_result_keys(schema)

      if results_key == :errores
        error = payload[results_key][results_topic_keys.first]
        raise Oca::Errors::BadRequest.new("Oca WS responded with:\n#{error[:description]}")
      elsif body = payload[results_key]
        if results_topic_keys.length > 1
          results_topic_keys.each_with_object({}) do |key, results|
            results[key] = body[key]
          end
        else
          body[results_topic_keys.first]
        end
      end
    end

    def parse_body(response, method)
      method_response = "#{method}_response".to_sym
      method_result = "#{method}_result".to_sym

      response.body[method_response][method_result]
    end

    private

    def get_result_keys(schema)
      elements = schema[:element][:complex_type][:choice][:element]

      key = schema[:@id].snakecase.to_sym
      topic_keys = ensure_array(elements).map do |element|
        element[:@name].snakecase.to_sym
      end

      [ key, topic_keys ]
    end

    def ensure_array(stuff)
      [stuff].flatten(1)
    end

  end
end
