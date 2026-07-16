# frozen_string_literal: true

module Events
  class CreateBatchService < BaseService
    MAX_LENGTH = ENV.fetch("LAGO_EVENTS_BATCH_MAX_LENGTH", 100).to_i

    Result = BaseResult[:events, :errors]

    def initialize(organization:, events_params:, timestamp:, metadata:)
      @organization = organization
      @events_params = events_params[:events]
      @timestamp = timestamp
      @metadata = metadata

      super
    end

    def call
      if events_params.blank?
        return result.single_validation_failure!(error_code: "no_events", field: :events)
      end

      if events_params.count > MAX_LENGTH
        return result.single_validation_failure!(error_code: "too_many_events", field: :events)
      end

      validate_events
      return result.validation_failure!(errors: result.errors) if result.errors.present?

      post_validate_events
      return result.validation_failure!(errors: result.errors) if result.errors.present?

      result
    end

    private

    attr_reader :organization, :events_params, :timestamp, :metadata

    def validate_events
      result.events = []
      result.errors = {}

      events_params.each_with_index do |event_params, index|
        event = Event.new
        event.organization_id = organization.id
        event.code = event_params[:code]
        event.transaction_id = event_params[:transaction_id]
        event.external_subscription_id = event_params[:external_subscription_id]
        event.properties = event_params[:properties] || {}
        event.metadata = metadata || {}
        event.timestamp = Time.zone.at(event_params[:timestamp] ? BigDecimal(event_params[:timestamp].to_s) : timestamp)
        event.precise_total_amount_cents = event_params[:precise_total_amount_cents]

        expression_result = CalculateExpressionService.call(organization:, event:)
        result.errors[index] = expression_result.error.message unless expression_result.success?

        result.events.push(event)
        result.errors[index] = event.errors.messages unless event.valid?
      rescue ArgumentError
        result.errors = result.errors.merge({index => {timestamp: ["invalid_format"]}})
      end
    end

    def post_validate_events
      if organization.postgres_events_store?
        bulk_insert_events
        return if result.errors.any?
      end

      KafkaProducerService.call!(events: result.events, organization:)
      enqueue_post_process_jobs if organization.postgres_events_store?
    end

    def bulk_insert_events
      records = result.events.map { |event| event.attributes.without("id", "created_at", "updated_at") }
      Event.transaction do
        saved_attributes = Event.insert_all(records, unique_by: :index_unique_transaction_id, returning: [:transaction_id, :id, :created_at, :updated_at]).rows # rubocop:disable Rails/SkipsModelValidations
        attributes_per_transaction_id = saved_attributes.index_by { |attrs| attrs[0] } # maps to { transaction_id => [transaction_id, id, created_at, updated_at] }

        result.events.each_with_index do |event, index|
          # We delete to ensure that any duplicate transaction_id in the input events_params
          # are caught and reported as errors.
          attrs = attributes_per_transaction_id.delete(event.transaction_id)
          if attrs
            # NOTE: even though we set id, created_at and updated_at here, the event is not considered as `.persisted?`
            # because ActiveRecord doesn't track that for bulk inserts.
            event.id = attrs[1]
            event.created_at = attrs[2]
            event.updated_at = attrs[3]
          else
            result.errors[index] = {transaction_id: ["value_already_exist"]}
          end
        end

        raise ActiveRecord::Rollback if result.errors.any?
      end
    end

    def enqueue_post_process_jobs
      jobs = result.events.map { |event| Events::PostProcessJob.new(event:) }
      ApplicationJob.perform_all_later(jobs)
    end
  end
end
