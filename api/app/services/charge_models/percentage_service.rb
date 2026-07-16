# frozen_string_literal: true

module ChargeModels
  class PercentageService < ChargeModels::BaseService
    protected

    def compute_amount
      # NOTE: if min/max per transacton are applied, we have to compute amount on a per transaction basis.
      #       In the future, this logic could also be applied for the free units / amount without min/max
      return compute_amount_with_transaction_min_max if should_apply_min_max?

      compute_percentage_amount + compute_fixed_amount
    end

    def compute_projected_amount
      current_amount = compute_amount
      return BigDecimal(0) if current_amount.zero? || period_ratio.nil? || period_ratio.zero?

      current_amount / BigDecimal(period_ratio.to_s)
    end

    def amount_details
      paid_units = units - free_units_value
      paid_units = 0 if paid_units.negative?
      paid_units.zero? ? BigDecimal(0) : compute_percentage_amount.fdiv(paid_units)
      free_events = if aggregation_result.count >= free_units_count
        free_units_count
      else
        aggregation_result.count
      end
      paid_events = aggregation_result.count - free_events

      {
        units: BigDecimal(units).to_s,
        free_units: BigDecimal(free_units_value).to_s,
        free_events:,
        paid_units: BigDecimal(paid_units).to_s,
        rate:,
        per_unit_total_amount: compute_percentage_amount,
        paid_events:,
        fixed_fee_unit_amount: paid_events.positive? ? fixed_amount : BigDecimal(0),
        fixed_fee_total_amount: compute_fixed_amount.to_s,
        min_max_adjustment_total_amount: min_max_adjustment_total_amount.to_s
      }
    end

    def unit_amount
      total_units = aggregation_result.full_units_number || units
      return 0 if total_units.zero?

      compute_amount / total_units
    end

    def compute_percentage_amount
      return 0 if free_units_value > units

      (units - free_units_value) * rate / 100
    end

    def compute_fixed_amount
      return 0.0 if units.zero?
      return 0.0 if fixed_amount.nil?
      return 0.0 if free_units_count >= aggregation_result.count

      (aggregation_result.count - free_units_count) * fixed_amount
    end

    # TODO: add memoization as this method is being called 4 times in the class
    # TODO: resect properties[:exclude_event] flag
    def free_units_value
      return 0 if last_running_total.zero?
      if free_units_per_events > 0 && free_units_per_events < (aggregation_result.options[:running_total]&.count || 0)
        return aggregation_result.options[:running_total][free_units_per_events - 1]
      end
      return last_running_total if free_units_per_total_aggregation.zero?
      return last_running_total if last_running_total <= free_units_per_total_aggregation

      free_units_per_total_aggregation
    end

    def free_units_count
      [
        free_units_per_events,
        aggregation_result.options[:running_total]&.count { |e| e < free_units_per_total_aggregation } || 0
      ].excluding(0).min || 0
    end

    def last_running_total
      @last_running_total ||= aggregation_result.options[:running_total]&.last || 0
    end

    def free_units_per_total_aggregation
      @free_units_per_total_aggregation ||= BigDecimal(properties["free_units_per_total_aggregation"] || 0)
    end

    def free_units_per_events
      @free_units_per_events ||= properties["free_units_per_events"].to_i
    end

    # NOTE: FE divides percentage rate with 100 and sends to BE.
    def rate
      BigDecimal(properties["rate"].to_s)
    end

    def fixed_amount
      @fixed_amount ||= BigDecimal((properties["fixed_amount"] || 0).to_s)
    end

    def per_transaction_max_amount?
      properties["per_transaction_max_amount"].present?
    end

    def per_transaction_min_amount?
      properties["per_transaction_min_amount"].present?
    end

    def per_transaction_max_amount
      BigDecimal(properties["per_transaction_max_amount"])
    end

    def per_transaction_min_amount
      BigDecimal(properties["per_transaction_min_amount"])
    end

    def should_apply_min_max?
      return false unless License.premium?

      per_transaction_max_amount? || per_transaction_min_amount?
    end

    def events_values
      # NOTE: when performing aggregation for pay in advance, we have to ignore the current event
      #       for computing the diff between event included and excluded
      #       see app/services/charges/apply_pay_in_advance_charge_model_service.rb:18
      aggregation_result.aggregator.per_event_aggregation(
        exclude_event: properties[:exclude_event],
        include_event_value: properties[:include_event_value],
        grouped_by_values: grouped_by
      ).event_aggregation
    end

    def compute_amount_with_transaction_min_max
      return @compute_amount_with_transaction_min_max if defined?(@compute_amount_with_transaction_min_max)

      remaining_free_events = free_units_per_events
      remaining_free_amount = free_units_per_total_aggregation

      @compute_amount_with_transaction_min_max ||= events_values.reduce(0) do |total_amount, event_value|
        value = event_value

        # NOTE: apply free events
        if remaining_free_events.positive? || remaining_free_amount.positive?
          remaining_free_events -= 1

          next 0 unless remaining_free_amount.positive?

          # NOTE: apply free amount
          if remaining_free_amount > value
            remaining_free_amount -= value
            next 0
          else
            value -= remaining_free_amount
            remaining_free_amount = 0
            remaining_free_events = 0
          end
        end

        # NOTE: apply rate
        event_amount = (value * rate) / 100

        # NOTE: apply fixed amount
        event_amount += fixed_amount

        # NOTE: apply min and max amount per transaction
        event_amount = apply_min_max(event_amount)

        total_amount + event_amount
      end
    end

    def apply_min_max(amount)
      return per_transaction_min_amount if per_transaction_min_amount? && amount < per_transaction_min_amount
      return per_transaction_max_amount if per_transaction_max_amount? && amount > per_transaction_max_amount

      amount
    end

    def min_max_adjustment_total_amount
      return BigDecimal(0) unless should_apply_min_max?

      BigDecimal(compute_amount_with_transaction_min_max - compute_percentage_amount - compute_fixed_amount)
    end
  end
end
