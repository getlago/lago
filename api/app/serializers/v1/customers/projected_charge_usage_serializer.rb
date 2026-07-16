# frozen_string_literal: true

module V1
  module Customers
    class ProjectedChargeUsageSerializer < ModelSerializer
      def serialize
        @grouped_data = precompute_groupings

        model.group_by(&:charge_id).map do |charge_id, fees|
          fee = fees.first
          usage_data = memoized_usage_data(fees)

          {
            **usage_data,
            charge: charge_data(fee),
            billable_metric: billable_metric_data(fee),
            filters: cached_filters(fees),
            grouped_usage: cached_grouped_usage(fees),
            presentation_breakdowns: V1::Customers::PresentationBreakdownBuilder.call(fees, filter: V1::Customers::PresentationBreakdownBuilder::UNGROUPED, filter_breakdown: V1::Customers::PresentationBreakdownBuilder::ALL),
            projected_presentation_breakdowns: project_ungrouped_presentation_breakdowns(fees)
          }
        end
      end

      private

      def calculate_usage_data(fees)
        {
          **current_usage_data(fees),
          **projected_usage_data(fees),
          pricing_unit_details: pricing_unit_details(fees)
        }
      end

      def current_usage_data(fees)
        totals = fees.each_with_object({
          units: BigDecimal(0),
          events_count: 0,
          amount_cents: 0
        }) do |fee, acc|
          acc[:units] += BigDecimal(fee.units)
          acc[:events_count] += fee.events_count.to_i
          acc[:amount_cents] += fee.amount_cents
        end

        {
          units: totals[:units].to_s,
          events_count: totals[:events_count],
          amount_cents: totals[:amount_cents],
          amount_currency: fees.first.amount_currency
        }
      end

      def projected_usage_data(fees)
        projection = memoized_projection(fees)

        {
          projected_units: projection[:units].to_s,
          projected_amount_cents: projection[:amount_cents].to_i,
          projected_presentation_breakdowns: projection[:presentation_breakdowns].map { |breakdown| ::V1::PresentationBreakdownSerializer.new(breakdown).serialize }
        }
      end

      def calculate_projection(fees)
        if charge_has_filters?(fees)
          calculate_filtered_projection(fees)
        elsif charge_has_grouping?(fees)
          calculate_grouped_projection(fees)
        else
          calculate_simple_projection(fees)
        end
      end

      def charge_has_filters?(fees)
        fees.first.charge&.filters&.any?
      end

      def charge_has_grouping?(fees)
        fees.any? { |f| f.grouped_by.present? }
      end

      def calculate_filtered_projection(fees)
        fees_with_defined_filters = fees.select(&:charge_filter_id)

        fees_with_defined_filters.reduce(initial_projection_values) do |totals, fee|
          result = ::Fees::ProjectionService.call!(fees: [fee])
          accumulate_projection(totals, result)
        end
      end

      def calculate_grouped_projection(fees)
        grouped_fees = fees.group_by(&:grouped_by).values

        grouped_fees.reduce(initial_projection_values) do |totals, group_fee_list|
          result = ::Fees::ProjectionService.call!(fees: group_fee_list)
          accumulate_projection(totals, result)
        end
      end

      def calculate_simple_projection(fees)
        result = ::Fees::ProjectionService.call!(fees: fees)

        {
          units: result.projected_units,
          amount_cents: result.projected_amount_cents,
          pricing_unit_amount_cents: result.projected_pricing_unit_amount_cents.to_i,
          presentation_breakdowns: result.projected_presentation_breakdowns
        }
      end

      def initial_projection_values
        {
          units: BigDecimal("0.0"),
          amount_cents: 0,
          pricing_unit_amount_cents: 0,
          presentation_breakdowns: []
        }
      end

      def accumulate_projection(totals, result)
        {
          units: totals[:units] + result.projected_units,
          amount_cents: totals[:amount_cents] + result.projected_amount_cents,
          pricing_unit_amount_cents: totals[:pricing_unit_amount_cents] + result.projected_pricing_unit_amount_cents.to_i,
          presentation_breakdowns: totals[:presentation_breakdowns].concat(result.projected_presentation_breakdowns)
        }
      end

      def pricing_unit_details(fees)
        fees.first.pricing_unit_usage&.then do |pricing_unit|
          {
            amount_cents: fees.map(&:pricing_unit_usage).compact.sum(&:amount_cents),
            projected_amount_cents: projected_pricing_unit_amount_cents(fees),
            short_name: pricing_unit.short_name,
            conversion_rate: pricing_unit.conversion_rate
          }
        end
      end

      def projected_pricing_unit_amount_cents(fees)
        memoized_projection(fees)[:pricing_unit_amount_cents]
      end

      def charge_data(fee)
        {
          lago_id: fee.charge_id,
          charge_model: fee.charge.charge_model,
          invoice_display_name: fee.charge.invoice_display_name
        }
      end

      def billable_metric_data(fee)
        metric = fee.billable_metric
        {
          lago_id: metric.id,
          name: metric.name,
          code: metric.code,
          aggregation_type: metric.aggregation_type
        }
      end

      def filters(fees)
        return [] unless fees.first.charge&.filters&.any?

        fees.group_by { |f| f.charge_filter&.id }
          .values
          .filter_map { |grouped_fees| build_filter_data(grouped_fees) }
      end

      def cached_filters(fees)
        return [] unless fees.first.charge&.filters&.any?

        @grouped_data[:by_charge_filter]
          .values
          .filter_map { |grouped_fees|
            next unless grouped_fees.first.charge_id == fees.first.charge_id
            build_filter_data(grouped_fees)
          }
      end

      def build_filter_data(grouped_fees)
        charge_filter = grouped_fees.first.charge_filter
        usage_data = memoized_usage_data(grouped_fees)

        {
          **usage_data.except(:amount_currency),
          invoice_display_name: charge_filter&.invoice_display_name,
          values: charge_filter&.to_h,
          presentation_breakdowns: V1::Customers::PresentationBreakdownBuilder.call(
            grouped_fees,
            filter: V1::Customers::PresentationBreakdownBuilder::ALL,
            filter_breakdown: V1::Customers::PresentationBreakdownBuilder::ALL
          )
        }
      end

      def grouped_usage(fees)
        return [] unless fees.any? { |f| f.grouped_by.present? }

        fees.group_by(&:grouped_by)
          .values
          .map { |grouped_fees| build_grouped_usage_data(grouped_fees) }
      end

      def cached_grouped_usage(fees)
        return [] unless fees.any? { |f| f.grouped_by.present? }

        @grouped_data[:by_grouped_by]
          .values
          .filter_map { |grouped_fees|
            next unless grouped_fees.first.charge_id == fees.first.charge_id
            build_grouped_usage_data(grouped_fees)
          }
      end

      def build_grouped_usage_data(grouped_fees)
        usage_data = memoized_usage_data(grouped_fees)

        {
          **usage_data.except(:amount_currency),
          grouped_by: grouped_fees.first.grouped_by,
          filters: filters(grouped_fees),
          presentation_breakdowns: V1::Customers::PresentationBreakdownBuilder.call(grouped_fees, filter: V1::Customers::PresentationBreakdownBuilder::GROUPED, filter_breakdown: V1::Customers::PresentationBreakdownBuilder::ALL)
        }
      end

      def precompute_groupings
        {
          by_charge_filter: model.group_by { |f| f.charge_filter&.id },
          by_grouped_by: model.group_by(&:grouped_by)
        }
      end

      def memoized_projection(fees)
        @projections ||= {}
        @projections[fees.object_id] ||= calculate_projection(fees)
      end

      def memoized_usage_data(fees)
        @usage_data_cache ||= {}
        @usage_data_cache[fees.object_id] ||= calculate_usage_data(fees)
      end

      def project_ungrouped_presentation_breakdowns(fees)
        ungrouped_fees = fees.reject { |f| f.grouped_by.present? }
        return [] if ungrouped_fees.empty?

        # NOTE: Since the memoization is done by object_id, we try as much as possible to reuse the memoized calculated data
        projection_fees = (ungrouped_fees.length == fees.length) ? fees : ungrouped_fees

        (memoized_projection(projection_fees)[:presentation_breakdowns] || []).map do |breakdown|
          ::V1::PresentationBreakdownSerializer.new(breakdown).serialize
        end
      end
    end
  end
end
