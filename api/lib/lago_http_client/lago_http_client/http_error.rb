# frozen_string_literal: true

module LagoHttpClient
  class HttpError < StandardError
    attr_reader :error_code, :error_body, :uri, :response_headers

    def initialize(code, body, uri, response_headers: {})
      @error_code = code
      @error_body = body
      @uri = uri
      @response_headers = response_headers
    end

    def message
      "HTTP #{error_code} - URI: #{uri}.\nError: #{error_body}\nResponse headers: #{response_headers}"
    end

    def json_message
      JSON.parse(error_body)
    rescue JSON::ParserError
      {}
    end
  end
end
