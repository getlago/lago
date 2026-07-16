# frozen_string_literal: true

module Types
  module Customers
    module Usage
      class ChargeFilter < Types::BaseObject
        graphql_name "ChargeFilterUsage"

        field :id, ID, null: true, method: :charge_filter_id

        field :amount_cents, GraphQL::Types::BigInt, null: false
        field :events_count, Integer, null: false
        field :invoice_display_name, String, null: true
        field :presentation_breakdowns, [Types::Customers::Usage::PresentationBreakdown], null: true
        field :pricing_unit_amount_cents, GraphQL::Types::BigInt, null: true
        field :units, GraphQL::Types::Float, null: false
        field :values, Types::ChargeFilters::Values, null: false

        def values
          object.charge_filter&.to_h || {} # rubocop:disable Lint/RedundantSafeNavigation
        end

        def pricing_unit_amount_cents
          object.pricing_unit_usage&.amount_cents
        end

        def invoice_display_name
          object.charge_filter&.invoice_display_name
        end

        def presentation_breakdowns
          Types::Fees::PresentationBreakdownBuilder.call(object, filter: Types::Fees::PresentationBreakdownBuilder::ALL, filter_breakdown: Types::Fees::PresentationBreakdownBuilder::ALL)
        end
      end
    end
  end
end
