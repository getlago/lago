# frozen_string_literal: true

module Utils
  # Produces security log events to Kafka for ClickHouse consumption.
  #
  # Security logs track user and system configuration changes:
  # user management, role changes, API key rotations, webhook configuration.
  #
  # Unlike Activity Logs, Security Logs:
  # - Do not track customer/subscription data
  # - Use flat resources map instead of polymorphic resource
  # - Require per-org premium integration (not just global `License.premium?`)
  # - Are collected ONLY for cloud Premium organizations
  class SecurityLog
    # Produces a security log event to Kafka.
    #
    # @param organization [Organization] the organization context
    # @param log_type [String] event category (e.g. "user", or "api_key")
    # @param log_event [String] specific event (e.g. "user.invited")
    # @param user [User, nil] the user who performed the action (nil for API key operations)
    # @param api_key [ApiKey, nil] the API key used for the action
    # @param resources [Hash] additional context (e.g., {invitee_email: "..."})
    # @param device_info [Hash] device metadata for login events
    # @return [Boolean] true if log was produced, false otherwise
    def self.produce(...)
      new(...).produce
    end

    # Checks if security logging infrastructure is available.
    #
    # @return [Boolean] true if ClickHouse, Kafka and topic are configured
    def self.available?
      ENV["LAGO_CLICKHOUSE_ENABLED"].present? &&
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"].present? &&
        topic.present?
    end

    def self.topic
      ENV["LAGO_KAFKA_SECURITY_LOGS_TOPIC"]
    end

    def initialize(
      organization:,
      log_type:,
      log_event:,
      user: nil,
      api_key: nil,
      resources: nil,
      device_info: nil,
      skip_organization_check: false
    )
      @organization = organization
      @skip_organization_check = skip_organization_check
      @log_type = log_type
      @log_event = log_event
      @user_id = resolve_user_id(user)
      @api_key_id = api_key&.id
      @resources = resources.to_h.stringify_keys
      @device_info = (device_info || CurrentContext.device_info).to_h.stringify_keys
      @current_time = Time.current.iso8601[...-1]
      @log_id = SecureRandom.uuid
      @key = "#{@organization.id}--#{@log_id}"
    end

    def produce
      return false unless self.class.available?
      return false unless @skip_organization_check || @organization.security_logs_enabled?

      KafkaProducer.produce_async(
        topic: self.class.topic,
        key: @key,
        payload: {
          organization_id: @organization.id,
          user_id: @user_id,
          api_key_id: @api_key_id,
          log_id: @log_id,
          log_type: @log_type,
          log_event: @log_event,
          device_info: @device_info,
          resources: @resources,
          logged_at: @current_time,
          created_at: @current_time
        }.to_json
      )
    end

    private

    def resolve_user_id(user)
      return user.id if user.present?
      return if CurrentContext.api_key_id.present?
      return if CurrentContext.membership.blank?

      Membership.find_by(
        organization_id: @organization.id,
        id: CurrentContext.membership.split("/").last
      )&.user_id
    end
  end
end
