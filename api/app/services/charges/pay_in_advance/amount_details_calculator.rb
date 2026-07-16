# frozen_string_literal: true

module Charges
  module PayInAdvance
    class AmountDetailsCalculator < BaseService
      AMOUNT_DETAILS_FOR_SINGLE_EVENT_ENABLED = %w[percentage graduated_percentage].freeze
      PERCENTAGE_CHARGE_AMOUNT_DETAILS_KEYS = %i[units free_units paid_units free_events paid_events fixed_fee_total_amount
        min_max_adjustment_total_amount per_unit_total_amount].freeze

      def initialize(charge:, applied_charge_model:, applied_charge_model_excluding_event:)
        @charge = charge
        @all_charges_details = applied_charge_model.amount_details
        @charges_details_without_last_event = applied_charge_model_excluding_event.amount_details
      end

      def call
        return {} unless AMOUNT_DETAILS_FOR_SINGLE_EVENT_ENABLED.include? charge.charge_model
        return {} if all_charges_details.blank? || charges_details_without_last_event.blank?

        if charge.percentage?
          calculate_percentage_charge_details
        elsif charge.graduated_percentage?
          calculate_graduated_percentage_charge_details
        end
      end

      private

      attr_reader :charge, :all_charges_details, :charges_details_without_last_event

      def calculate_percentage_charge_details
        fixed_values = {rate: all_charges_details[:rate], fixed_fee_unit_amount: all_charges_details[:fixed_fee_unit_amount]}
        details = PERCENTAGE_CHARGE_AMOUNT_DETAILS_KEYS.each_with_object(fixed_values) do |key, result|
          result[key] = (BigDecimal(all_charges_details[key].to_s) - BigDecimal(charges_details_without_last_event[key].to_s)).to_s
        end
        # TODO: remove this when ChargeModels::PercentageService#free_units_value respects :exclude_event flag
        details[:free_units] = (BigDecimal(details[:units].to_s) - BigDecimal(details[:paid_units].to_s)).to_s
        details
      end

      def calculate_graduated_percentage_charge_details
        calculated_ranges = all_charges_details[:graduated_percentage_ranges].map do |range_with_last_event|
          corresponding_range_without_last_event = charges_details_without_last_event[:graduated_percentage_ranges].find do |range|
            range[:from_value] == range_with_last_event[:from_value] && range[:to_value] == range_with_last_event[:to_value]
          end || Hash.new(0)

          total_with_flat_amount = range_with_last_event[:total_with_flat_amount] - corresponding_range_without_last_event[:total_with_flat_amount]
          units = BigDecimal(range_with_last_event[:units].to_s) - BigDecimal(corresponding_range_without_last_event[:units].to_s)
          {
            from_value: range_with_last_event[:from_value],
            to_value: range_with_last_event[:to_value],
            flat_unit_amount: range_with_last_event[:flat_unit_amount] - corresponding_range_without_last_event[:flat_unit_amount],
            rate: range_with_last_event[:rate],
            units: units.to_s,
            per_unit_total_amount: (units > 0) ? (total_with_flat_amount / units).round(2).to_s : "0.0",
            total_with_flat_amount: total_with_flat_amount
          }
        end
        {graduated_percentage_ranges: calculated_ranges}
      end
    end
  end
end
