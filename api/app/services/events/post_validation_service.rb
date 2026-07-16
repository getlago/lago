# frozen_string_literal: true

module Events
  class PostValidationService < BaseService
    Result = BaseResult[:errors]

    def initialize(organization:)
      @organization = organization

      super
    end

    def call
      errors = {
        invalid_code: process_query(invalid_code_query),
        missing_aggregation_property: process_query(missing_aggregation_property_query),
        invalid_filter_values: process_query(invalid_filter_values_query)
      }

      if errors[:invalid_code].present? ||
          errors[:missing_aggregation_property].present? ||
          errors[:invalid_filter_values].present?
        deliver_webhook(errors)
      end

      result.errors = errors
      result
    end

    private

    attr_reader :organization

    def invalid_code_query
      <<-SQL
        SELECT DISTINCT transaction_id
        FROM last_hour_events_mv
        WHERE organization_id = '#{organization.id}'
          AND billable_metric_code IS NULL
      SQL
    end

    def missing_aggregation_property_query
      <<-SQL
        SELECT DISTINCT transaction_id
        FROM last_hour_events_mv
        WHERE organization_id = '#{organization.id}'
          AND (
            (
              field_name_mandatory = 't'
              AND field_value IS NULL
            )
            OR (
              numeric_field_mandatory = 't'
              AND is_numeric_field_value = 'f'
            )
          )
      SQL
    end

    def invalid_filter_values_query
      <<-SQL
        SELECT DISTINCT transaction_id
        FROM last_hour_events_mv
        WHERE organization_id = '#{organization.id}'
          AND has_filter_keys = 't'
          AND has_valid_filter_values = 'f'
      SQL
    end

    def process_query(sql)
      ApplicationRecord.connection.select_all(sql).rows.map(&:first)
    end

    def deliver_webhook(errors)
      SendWebhookJob.perform_later("events.errors", organization, errors:)
    end
  end
end
