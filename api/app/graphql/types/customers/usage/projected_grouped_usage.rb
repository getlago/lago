# frozen_string_literal: true

module Types
  module Customers
    module Usage
      class ProjectedGroupedUsage < Types::BaseObject
        graphql_name "ProjectedGroupedChargeUsage"

        delegate :projected_units, :projected_amount_cents, to: :projection_result

        field :amount_cents, GraphQL::Types::BigInt, null: false
        field :events_count, Integer, null: false
        field :id, ID, null: false
        field :pricing_unit_amount_cents, GraphQL::Types::BigInt, null: true
        field :pricing_unit_projected_amount_cents, GraphQL::Types::BigInt, null: true
        field :projected_amount_cents, GraphQL::Types::BigInt, null: false
        field :projected_units, GraphQL::Types::Float, null: false
        field :units, GraphQL::Types::Float, null: false

        field :filters, [Types::Customers::Usage::ProjectedChargeFilter], null: true
        field :grouped_by, GraphQL::Types::JSON, null: true
        field :presentation_breakdowns, [Types::Customers::Usage::PresentationBreakdown], null: true
        field :projected_presentation_breakdowns, [Types::Customers::Usage::PresentationBreakdown], null: true

        def id
          SecureRandom.uuid
        end

        def amount_cents
          object.sum(&:amount_cents)
        end

        def pricing_unit_amount_cents
          return if object.first.charge.applied_pricing_unit.nil?

          object.map(&:pricing_unit_usage).sum(&:amount_cents)
        end

        def pricing_unit_projected_amount_cents
          projection_result.projected_pricing_unit_amount_cents
        end

        def events_count
          object.sum(&:events_count)
        end

        def units
          object.map { |f| BigDecimal(f.units) }.sum
        end

        def grouped_by
          object.first.grouped_by
        end

        def filters
          return [] unless object.first.has_charge_filters?

          object.sort_by { |f| f.charge_filter&.display_name.to_s }
        end

        def presentation_breakdowns
          @presentation_breakdowns ||= Types::Fees::PresentationBreakdownBuilder.call(
            object,
            filter: Types::Fees::PresentationBreakdownBuilder::GROUPED,
            filter_breakdown: Types::Fees::PresentationBreakdownBuilder::ALL
          )
        end

        def projected_presentation_breakdowns
          return [] if presentation_breakdowns.empty?

          projection_result.projected_presentation_breakdowns
        end

        private

        def projection_result
          @projection_result ||= ::Fees::ProjectionService.call!(fees: object)
        end
      end
    end
  end
end
