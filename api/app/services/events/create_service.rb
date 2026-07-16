# frozen_string_literal: true

module Events
  class CreateService < BaseService
    Result = BaseResult[:event]

    def initialize(organization:, params:, timestamp:, metadata:)
      @organization = organization
      @params = params
      @timestamp = timestamp
      @metadata = metadata
      super
    end

    def call
      event = Event.new
      event.organization_id = organization.id
      event.code = params[:code]
      event.transaction_id = params[:transaction_id]
      event.external_subscription_id = params[:external_subscription_id]
      event.properties = params[:properties] || {}
      event.metadata = metadata || {}
      event.timestamp = Time.zone.at(params[:timestamp] ? BigDecimal(params[:timestamp].to_s) : timestamp)
      event.precise_total_amount_cents = params[:precise_total_amount_cents]

      expression_result = CalculateExpressionService.call(organization:, event:)
      return result.validation_failure!(errors: expression_result.error.message) unless expression_result.success?

      event.save! unless organization.clickhouse_events_store?

      result.event = event

      produce_kafka_event(event)
      Events::PostProcessJob.perform_later(event:) unless organization.clickhouse_events_store?

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :transaction_id, error_code: "value_already_exist")
    rescue ArgumentError
      result.single_validation_failure!(field: :timestamp, error_code: "invalid_format")
    end

    private

    attr_reader :organization, :params, :timestamp, :metadata

    def produce_kafka_event(event)
      Events::KafkaProducerService.call!(events: event, organization:)
    end
  end
end
