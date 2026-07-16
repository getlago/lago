# frozen_string_literal: true

module Charges
  class BulkForecastedUsageAmountService < BaseService
    Result = BaseResult[:results, :failed_charges, :processed_count, :failed_count]

    def initialize(charges_data:)
      @charges_data = charges_data
      super
    end

    def call
      charge_ids = charges_data.map { |cd| cd[:charge_id] }.compact.uniq
      charge_filter_ids = charges_data.map { |cd| cd[:charge_filter_id] }.compact.uniq.reject(&:blank?)

      charges_lookup = Charge.where(id: charge_ids).index_by(&:id)
      charge_filters_lookup = charge_filter_ids.any? ?
                             ChargeFilter.where(id: charge_filter_ids).index_by(&:id) : {}

      results = []
      failed_charges = []

      charges_data.each do |charge_data|
        charge = charges_lookup[charge_data[:charge_id]]
        charge_filter = charge_data[:charge_filter_id].present? ?
                       charge_filters_lookup[charge_data[:charge_filter_id]] : nil
        record_id = charge_data[:record_id]

        unless charge
          raise ActiveRecord::RecordNotFound, "Charge not found: #{charge_data[:charge_id]}"
        end

        if charge_data[:charge_filter_id].present? && !charge_filter
          raise ActiveRecord::RecordNotFound, "ChargeFilter not found: #{charge_data[:charge_filter_id]}"
        end

        percentile_results = {}

        [:units_conservative, :units_realistic, :units_optimistic].each do |percentile_key|
          units = charge_data[percentile_key]
          next unless units

          price_result = Charges::CalculatePriceService.call(
            units: units,
            charge: charge,
            charge_filter: charge_filter
          )

          if price_result.success?
            suffix = percentile_key.to_s.gsub("units_", "")
            percentile_results[:"charge_amount_cents_#{suffix}"] = price_result.charge_amount_cents * 100
            percentile_results[:"subscription_amount_cents_#{suffix}"] = price_result.subscription_amount_cents * 100
            percentile_results[:"total_amount_cents_#{suffix}"] = price_result.total_amount_cents * 100
          end
        end

        results << {
          record_id: record_id,
          charge_id: charge_data[:charge_id],
          charge_filter_id: charge_data[:charge_filter_id],
          **percentile_results
        }
      rescue => e
        failed_charges << {
          record_id: record_id,
          charge_id: charge_data[:charge_id],
          error: e.message
        }
      end

      result.results = results
      result.failed_charges = failed_charges
      result.processed_count = results.length
      result.failed_count = failed_charges.length

      response_summary = {
        failed_charges: failed_charges,
        processed_count: result.processed_count,
        failed_count: result.failed_count
      }

      Rails.logger.info "[ChargesController] Response summary: #{response_summary}"

      result
    end

    private

    attr_reader :charges_data
  end
end
