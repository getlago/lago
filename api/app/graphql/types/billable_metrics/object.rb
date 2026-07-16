# frozen_string_literal: true

module Types
  module BillableMetrics
    class Object < Types::BaseObject
      graphql_name "BillableMetric"
      description "Base billable metric"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType

      field :code, String, null: false
      field :name, String, null: false

      field :description, String

      field :aggregation_type, Types::BillableMetrics::AggregationTypeEnum, null: false
      field :expression, String, null: true
      field :field_name, String, null: true
      field :weighted_interval, Types::BillableMetrics::WeightedIntervalEnum, null: true

      field :filters, [Types::BillableMetricFilters::Object], null: true

      field :recurring, Boolean, null: false

      field :has_active_subscriptions, Boolean, null: false
      field :has_draft_invoices, Boolean, null: false
      field :has_plans, Boolean, null: false, method: :attached_to_plan?
      field :has_subscriptions, Boolean, null: false

      field :rounding_function, Types::BillableMetrics::RoundingFunctionEnum, null: true
      field :rounding_precision, Integer, null: true

      field :activity_logs, [Types::ActivityLogs::Object], null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :integration_mappings, [Types::IntegrationMappings::Object], null: true do
        argument :integration_id, ID, required: false
      end

      def has_active_subscriptions
        object.attached_subscriptions.active.exists?
      end

      def has_subscriptions
        object.attached_subscriptions.exists?
      end

      def has_draft_invoices
        object.invoices.draft.exists?
      end

      def integration_mappings(integration_id: nil)
        mappings = object.integration_mappings
        mappings = mappings.where(integration_id:) if integration_id
        mappings
      end
    end
  end
end
