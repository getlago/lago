# frozen_string_literal: true

module Utils
  class ApiLog
    def self.produce(*, **, &)
      new(*, **, &).produce
    end

    def self.available?
      ENV["LAGO_CLICKHOUSE_ENABLED"].present? &&
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"].present? &&
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"].present?
    end

    def initialize(request, response, organization:, &block)
      @request = request
      @response = response
      @organization = organization
      @request_id = request.request_id.presence || SecureRandom.uuid
      @block = block
    end

    def produce
      return unless self.class.available?

      current_time = Time.current.iso8601[...-1]
      KafkaProducer.produce_async(
        topic: ENV["LAGO_KAFKA_API_LOGS_TOPIC"],
        key:,
        payload: {
          **payload,
          logged_at: current_time,
          created_at: current_time
        }.to_json
      )
    end

    private

    attr_reader :request, :response, :organization, :request_id, :block

    def key
      "#{organization.id}--#{request_id}"
    end

    def payload
      {
        request_id:,
        organization_id: organization.id,
        api_key_id: CurrentContext.api_key_id,
        api_version:,
        **request_data,
        **response_data
      }
    end

    def request_data
      {
        client: request.user_agent,
        request_body: request.params.except(:controller, :action, :format),
        request_path: request.path,
        request_origin: request.base_url,
        http_method: request.method_symbol
      }
    end

    def response_data
      {
        request_response: response.body.present? ? JSON.parse(response.body) : nil,
        http_status: response.status
      }
    end

    def api_version
      request.path.match(/\/api\/(?<version>v\d+)\/.*/)[:version]
    end
  end
end
