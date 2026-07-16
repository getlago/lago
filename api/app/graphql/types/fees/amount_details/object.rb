# frozen_string_literal: true

module Types
  module Fees
    module AmountDetails
      class Object < Types::BaseObject
        graphql_name "FeeAmountDetails"

        # NOTE: Graduated charge model
        field :graduated_ranges, [Types::Fees::AmountDetails::GraduatedRange], null: true

        # NOTE: Graduated percentage modle
        field :graduated_percentage_ranges, [Types::Fees::AmountDetails::GraduatedPercentageRange], null: true

        # NOTE: Package charge model
        field :per_package_size, Integer, null: true
        field :per_package_unit_amount, String, null: true

        # NOTE: Percentage charge model
        field :fixed_fee_total_amount, String, null: true
        field :fixed_fee_unit_amount, String, null: true
        field :free_events, Integer, null: true
        field :min_max_adjustment_total_amount, String, null: true
        field :paid_events, Integer, null: true
        field :rate, String, null: true
        field :units, String, null: true

        # NOTE: Volume charge model
        field :flat_unit_amount, String, null: true
        field :per_unit_amount, String, null: true

        # NOTE: Percentage & Volume charge model
        field :per_unit_total_amount, String, null: true

        # NOTE: Package & Percentage charge model
        field :free_units, String, null: true
        field :paid_units, String, null: true
      end
    end
  end
end
