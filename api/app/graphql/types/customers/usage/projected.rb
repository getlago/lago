# frozen_string_literal: true

module Types
  module Customers
    module Usage
      class Projected < Types::BaseObject
        graphql_name "CustomerProjectedUsage"

        field :from_datetime, GraphQL::Types::ISO8601DateTime, null: false
        field :to_datetime, GraphQL::Types::ISO8601DateTime, null: false

        field :currency, Types::CurrencyEnum, null: false
        field :issuing_date, GraphQL::Types::ISO8601Date, null: false

        field :amount_cents, GraphQL::Types::BigInt, null: false
        field :projected_amount_cents, GraphQL::Types::BigInt, null: false
        field :taxes_amount_cents, GraphQL::Types::BigInt, null: false
        field :total_amount_cents, GraphQL::Types::BigInt, null: false

        field :charges_usage, [Types::Customers::Usage::ProjectedCharge], null: false

        def charges_usage
          object.fees.group_by(&:charge_id).values
        end

        def projected_amount_cents
          fee_groups_by_charge.sum { |fee_group| projected_amount_for_fee_group(fee_group) }
        end

        private

        def fee_groups_by_charge
          object.fees.group_by(&:charge_id).values
        end

        def projected_amount_for_fee_group(fee_group)
          charge = fee_group.first.charge

          if charge.filters.any?
            projected_amount_for_filtered_fees(fee_group)
          elsif has_grouping?(fee_group)
            projected_amount_for_grouped_fees(fee_group)
          else
            projected_amount_for_simple_fees(fee_group)
          end
        end

        def has_grouping?(fee_group)
          fee_group.any? { |f| f.grouped_by.present? }
        end

        def projected_amount_for_filtered_fees(fee_group)
          defined_filter_fees = fee_group.select(&:charge_filter_id)
          defined_filter_fees.sum { |fee| project_fees([fee]) }
        end

        def projected_amount_for_grouped_fees(fee_group)
          groups = fee_group.group_by(&:grouped_by).values
          groups.sum { |single_group_fees| project_fees(single_group_fees) }
        end

        def projected_amount_for_simple_fees(fee_group)
          project_fees(fee_group)
        end

        def project_fees(fees)
          ::Fees::ProjectionService.call!(fees: fees).projected_amount_cents
        end
      end
    end
  end
end
