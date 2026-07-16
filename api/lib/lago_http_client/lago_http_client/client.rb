# frozen_string_literal: true

require "net/http/post/multipart"
require "event_stream_parser"
require "openssl"

module LagoHttpClient
  class Client
    RESPONSE_SUCCESS_CODES = [200, 201, 202, 204].freeze
    MAX_RETRIES_ATTEMPTS = 3
    RETRYABLE_HTTP_STATUSES = [500, 502, 503, 504].freeze
    TRANSIENT_ERROR_CLASSES = [
      OpenSSL::SSL::SSLError,
      Net::OpenTimeout,
      Net::ReadTimeout,
      EOFError,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH
    ].freeze
    RETRY_BACKOFF_RANGE = (0.25..0.5)

    attr_reader :uri, :retries_on, :retry_on_transient_errors

    def initialize(url, open_timeout: nil, read_timeout: nil, write_timeout: nil, retries_on: [], retry_on_transient_errors: false)
      @uri = URI(url)
      @http_client = Net::HTTP.new(uri.host, uri.port)
      @http_client.open_timeout = open_timeout if open_timeout.present?
      @http_client.read_timeout = read_timeout if read_timeout.present?
      @http_client.write_timeout = write_timeout if write_timeout.present?
      @http_client.use_ssl = true if uri.scheme == "https"
      @retries_on = retries_on
      @retry_on_transient_errors = retry_on_transient_errors
    end

    def post(body, headers)
      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")

      headers.each do |header|
        key = header.keys.first
        value = header[key]
        req[key] = value
      end

      req.body = body.to_json
      response = request(req)

      JSON.parse(response.body.presence || "{}")
    rescue JSON::ParserError
      response.body.presence || "{}"
    end

    def post_with_response(body, headers)
      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")

      headers.keys.each do |key|
        req[key] = headers[key]
      end

      req.body = body.to_json
      request(req)
    end

    def put_with_response(body, headers)
      req = Net::HTTP::Put.new(uri.request_uri, "Content-Type" => "application/json")

      headers.keys.each do |key|
        req[key] = headers[key]
      end

      req.body = body.to_json
      request(req)
    end

    def post_multipart_file(params = {})
      req = Net::HTTP::Post::Multipart.new(
        uri.path,
        params
      )

      request(req)
    end

    def post_url_encoded(params, headers)
      encoded_form = URI.encode_www_form(params)

      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/x-www-form-urlencoded")
      headers.keys.each do |key|
        req[key] = headers[key]
      end

      response = request(req, encoded_form)
      JSON.parse(response.body.presence || "{}")
    end

    def post_with_stream(body, headers = {}, &block)
      req = Net::HTTP::Post.new(uri.request_uri, {"Content-Type" => "application/json"}.merge(headers))
      req.body = body.to_json

      parser = EventStreamParser::Parser.new

      http_client.start do |http|
        http.request(req) do |response|
          raise_error(response) unless RESPONSE_SUCCESS_CODES.include?(response.code.to_i)

          response.read_body do |chunk|
            parser.feed(chunk) do |type, data, id, reconnection_time|
              yield(type, data, id, reconnection_time) if block_given?
            end
          end
        end
      end
    end

    def get(headers: {}, params: nil, body: nil, content_type: nil)
      path = params ? "#{uri.path}?#{URI.encode_www_form(params)}" : uri.path
      req = Net::HTTP::Get.new(path)

      if body.present?
        req["Content-Type"] = content_type if content_type
        req.body = if content_type == "application/json"
          body.to_json
        else
          URI.encode_www_form(body)
        end
      end

      headers.keys.each do |key|
        req[key] = headers[key]
      end

      response = request(req)
      JSON.parse(response.body.presence || "{}")
    end

    private

    attr_reader :http_client

    def raise_error(response)
      raise(
        ::LagoHttpClient::HttpError.new(response.code, response.body, uri, response_headers: response.each_header.to_h)
      )
    end

    def request(req, params = nil)
      attempt = 0

      begin
        attempt += 1
        response = http_client.request(req, params)
        raise_error(response) unless RESPONSE_SUCCESS_CODES.include?(response.code.to_i)
        response
      rescue => e
        if retryable?(e) && attempt < MAX_RETRIES_ATTEMPTS
          backoff
          retry
        end

        raise
      end
    end

    # An error is retryable when its class was explicitly opted in through
    # `retries_on:`, or when `retry_on_transient_errors` is enabled and the error
    # is a known transient failure (a connection-level exception or a transient
    # HTTP status such as 502/503).
    def retryable?(error)
      return true if retries_on.include?(error.class)
      return false unless retry_on_transient_errors

      transient_exception?(error) || transient_http_error?(error)
    end

    def transient_exception?(error)
      TRANSIENT_ERROR_CLASSES.any? { |klass| error.is_a?(klass) }
    end

    def transient_http_error?(error)
      error.is_a?(::LagoHttpClient::HttpError) && RETRYABLE_HTTP_STATUSES.include?(error.error_code.to_i)
    end

    def backoff
      sleep(rand(RETRY_BACKOFF_RANGE))
    end
  end
end
