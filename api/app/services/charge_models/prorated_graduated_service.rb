# frozen_string_literal: true

module ChargeModels
  class ProratedGraduatedService < ChargeModels::BaseService
    protected

    def ranges
      properties["graduated_ranges"]&.map(&:with_indifferent_access)
    end

    def compute_amount
      full_units = per_event_aggregation_result.event_aggregation

      prorated_units = if per_event_aggregation_result.respond_to?(:event_prorated_aggregation)
        per_event_aggregation_result.event_prorated_aggregation
      else
        []
      end
      units_count = prorated_units.count

      index = 0
      overflow = 0
      full_sum = 0
      max_full_sum = 0
      prorated_sum = 0
      result_amount = 0

      return 0 if units.zero?

      # Calculate total prorated value inside the tier. The goal is to iterate over both arrays (prorated and full)
      # and determine which prorated events goes into certain tier. Full units sum determines tier while
      # prorated units sum determines amount that is going to be used for price calculation inside the tier.
      # Overflow can happen if event value covers partially both lower and higher tier
      while (index < units_count) || !overflow.zero?
        range = range(full_sum, overflow, full_units[index])

        # Here is applied overflow from previous iteration (if any)
        unless overflow.zero?
          prorated_sum += overflow * prorated_coefficient(prorated_units[index - 1], full_units[index - 1])
          # This condition handles multiple overflows. E.g. We have two tiers: 0 - 5, 6 - inf.
          # There is only one event whose value is 75. There will be overflow for each tier and we need to
          # calculate it for each tier
          if range[:to_value] && full_sum >= range[:to_value]
            overflow = full_sum - range[:to_value]
            prorated_sum -= overflow * prorated_coefficient(prorated_units[index - 1], full_units[index - 1])
            result_amount += prorated_sum * BigDecimal(range[:per_unit_amount])
            prorated_sum = 0

            next
          end

          overflow = 0
        end

        # If we are into highest range and overflow is handled we should exit the loop if there is no more events
        break if prorated_units[index].nil?

        # Skip ADD events with zero prorated value - they shouldn't affect tier assignment.
        # For example, when a REMOVE before the current billing period.
        if prorated_units[index].zero? && full_units[index].positive?
          index += 1
          next
        end

        # Skip REMOVE events whose corresponding add was skipped (orphan removes).
        # These are identified by having zero prorated value AND would make full_sum negative
        # (indicating the matching add event was skipped).
        # Note: Remove events within the current period also have prorated_value = 0 by design,
        # but they won't make full_sum negative because their matching add was processed.
        if prorated_units[index].zero? && full_units[index].negative? && (full_sum + full_units[index]).negative?
          index += 1
          next
        end

        full_sum += full_units[index]
        max_full_sum = full_sum if full_sum > max_full_sum
        prorated_sum += prorated_units[index]

        index += 1

        next if skip_overflow_calculation?(full_sum, range[:to_value], range[:from_value])

        # Calculating overflow (if any) and aligning current invalid prorated sum with prorated overflow amount
        overflow = calculate_overflow(full_sum, range[:to_value], range[:from_value])
        prorated_sum -= overflow * prorated_coefficient(prorated_units[index - 1], full_units[index - 1])

        result_amount += prorated_sum * BigDecimal(range[:per_unit_amount])
        prorated_sum = 0
      end

      result_amount += prorated_sum * BigDecimal(range[:per_unit_amount]) # Applying units from highest range

      result_with_flat_amount(result_amount, full_sum, max_full_sum)
    end

    def compute_projected_amount
      current_amount = compute_amount
      return BigDecimal(0) if current_amount.zero? || period_ratio.nil? || period_ratio.zero?

      current_amount / BigDecimal(period_ratio.to_s)
    end

    def unit_amount
      total_units = per_event_aggregation_result.event_aggregation.sum
      return 0 if total_units.zero?

      compute_amount / total_units
    end

    private

    def result_with_flat_amount(result, total_full_units, max_full_units)
      return 0 if units.zero? || total_full_units.negative?

      flat_amount = 0
      result = 0 if result.negative?

      ranges.each do |range|
        flat_amount += BigDecimal(range[:flat_amount])

        return result + flat_amount if range[:to_value].nil? || max_full_units <= range[:to_value]
      end
    end

    def range(full_units, overflow, next_full_unit)
      return ranges[0] if full_units <= 0

      units = if overflow.zero?
        full_units
      else
        overflow.positive? ? (full_units - overflow + 1) : (full_units + overflow)
      end

      ranges.each_with_index do |range, index|
        return ranges[index + 1] if units == range[:to_value] && next_full_unit&.positive?
        return range if units == range[:to_value]
        return range if units >= range[:from_value] && (range[:to_value].nil? || units < range[:to_value])
      end

      ranges[0]
    end

    def calculate_overflow(full_sum, to_value, from_value)
      return full_sum - from_value + 1 if to_value.nil?

      if full_sum >= to_value
        full_sum - to_value
      else
        full_sum - from_value + 1
      end
    end

    def per_event_aggregation_result
      @per_event_aggregation_result ||= aggregation_result.aggregator.per_event_aggregation(
        grouped_by_values: grouped_by
      )
    end

    def prorated_coefficient(prorated_value, full_value)
      prorated_value.fdiv(full_value)
    end

    def skip_overflow_calculation?(full_sum, to_value, from_value)
      return full_sum >= from_value - 1 if to_value.nil?

      full_sum < to_value && full_sum >= from_value
    end
  end
end
