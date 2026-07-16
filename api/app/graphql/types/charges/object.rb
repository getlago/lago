# frozen_string_literal: true

module Types
  module Charges
    class Object < Types::BaseObject
      graphql_name "Charge"

      field :code, String, null: true
      field :id, ID, null: false
      field :invoice_display_name, String, null: true
      field :parent_id, ID, null: true

      field :billable_metric, Types::BillableMetrics::Object, null: false
      field :charge_model, Types::Charges::ChargeModelEnum, null: false
      field :invoiceable, Boolean, null: false
      field :min_amount_cents, GraphQL::Types::BigInt, null: false
      field :pay_in_advance, Boolean, null: false
      field :properties, Types::Charges::Properties, null: true
      field :prorated, Boolean, null: false
      field :regroup_paid_fees, Types::Charges::RegroupPaidFeesEnum, null: true

      field :filters, [Types::ChargeFilters::Object], null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :applied_pricing_unit, Types::AppliedPricingUnits::Object, null: true
      field :taxes, [Types::Taxes::Object]

      def properties
        return object.properties unless object.properties == "{}"

        JSON.parse(object.properties)
      end

      def billable_metric
        return object.billable_metric unless object.discarded?

        BillableMetric.with_discarded.find_by(id: object.billable_metric_id)
      end
    end
  end
end
