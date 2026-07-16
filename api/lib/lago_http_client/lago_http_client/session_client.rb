# frozen_string_literal: true

module LagoHttpClient
  class SessionClient
    RESPONSE_SUCCESS_CODES = [200, 201, 202, 204].freeze
    MAX_RETRIES_ATTEMPTS = 3

    attr_reader :base_url, :cookies

    def initialize(base_url, read_timeout: 30, open_timeout: 30)
      @base_url = base_url
      @read_timeout = read_timeout
      @open_timeout = open_timeout
      @cookies = []
    end

    def get(path, headers: {})
      uri = URI.join(base_url, path)
      http = create_http_client(uri)

      request = Net::HTTP::Get.new(uri.path)
      apply_headers(request, headers)
      inject_cookies(request)

      execute_request(request, http)
    end

    def post(path, body: {}, headers: {})
      uri = URI.join(base_url, path)
      http = create_http_client(uri)

      request = Net::HTTP::Post.new(uri.path)
      apply_headers(request, headers)
      inject_cookies(request)
      request.body = format_body(body, headers)

      execute_request(request, http)
    end

    def clear_cookies
      @cookies = []
    end

    private

    attr_reader :read_timeout, :open_timeout

    def create_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)

      if uri.scheme == "https"
        http.use_ssl = true
        if Rails.env.development? || Rails.env.test?
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      http.read_timeout = read_timeout
      http.open_timeout = open_timeout
      http
    end

    def execute_request(request, http_client)
      attempt = 0

      begin
        attempt += 1
        response = http_client.request(request)
        store_cookies(response)
        validate_response(response)
        response
      rescue OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout
        retry if attempt < MAX_RETRIES_ATTEMPTS
        raise
      end
    end

    def apply_headers(request, headers)
      headers.each do |key, value|
        request[key] = value
      end
    end

    def inject_cookies(request)
      return if cookies.empty?

      request["Cookie"] = cookies.join("; ")
    end

    def format_body(body, headers)
      content_type = headers["Content-Type"] || headers["content-type"]

      case content_type
      when "application/json"
        body.to_json
      when "application/x-www-form-urlencoded"
        URI.encode_www_form(body)
      else
        body.is_a?(String) ? body : body.to_json
      end
    end

    def store_cookies(response)
      return unless response["Set-Cookie"]

      new_cookies = response.get_fields("Set-Cookie")
      return unless new_cookies

      new_cookies.each do |cookie|
        cookie_value = cookie.split(";").first
        cookie_name = cookie_value.split("=").first

        @cookies.reject! { |c| c.start_with?("#{cookie_name}=") }
        @cookies << cookie_value
      end
    end

    def validate_response(response)
      return if RESPONSE_SUCCESS_CODES.include?(response.code.to_i)
      return if response.is_a?(Net::HTTPRedirection)

      raise LagoHttpClient::HttpError.new(
        response.code,
        response.body,
        URI.join(base_url, response.uri || ""),
        response_headers: response.each_header.to_h
      )
    end
  end
end
