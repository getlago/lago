# frozen_string_literal: true

module ChargeModels
  module FilterProperties
    class ChargeService < BaseService
      protected

      def base_attributes
        chargeable.billable_metric.custom_agg? ? [:custom_properties] : []
      end

      def charge_model_attributes
        attributes = super

        case charge_model&.to_sym
        when :graduated_percentage
          attributes += %i[graduated_percentage_ranges]
        when :package
          attributes += %i[amount free_units package_size]
        when :percentage
          attributes += %i[
            fixed_amount
            free_units_per_events
            free_units_per_total_aggregation
            per_transaction_max_amount
            per_transaction_min_amount
            rate
          ]
        end

        attributes
      end
    end
  end
end
