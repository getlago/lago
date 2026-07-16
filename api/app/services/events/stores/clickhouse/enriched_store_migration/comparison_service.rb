# frozen_string_literal: true

require "benchmark"

module Events
  module Stores
    module Clickhouse
      module EnrichedStoreMigration
        class ComparisonService < BaseService
          Result = BaseResult[:diff_count, :fee_details, :legacy_elapsed, :enriched_elapsed]

          FieldDiff = Data.define(:legacy, :enriched)
          FeeValues = Data.define(:units, :amount_cents, :events_count, :total_aggregated_units)
          FeeDetail = Data.define(
            :charge_id, :charge_filter_id, :grouped_by,
            :billable_metric_code, :aggregation_type, :charge_model,
            :from, :to, :status, :legacy, :enriched, :diffs
          )

          def initialize(subscription:, deduplicate: false)
            @subscription = subscription
            @organization = subscription.organization
            @deduplicate = deduplicate
            super
          end

          def call
            result.fee_details = []

            legacy_usage_result = nil
            result.legacy_elapsed = Benchmark.realtime do
              legacy_usage_result = compute_usage(enriched: false)
            end

            return result.fail_with_error!(legacy_usage_result.error) if legacy_usage_result.failure?

            enriched_usage_result = nil
            result.enriched_elapsed = Benchmark.realtime do
              enriched_usage_result = compute_usage(enriched: true)
            end

            return result.fail_with_error!(enriched_usage_result.error) if enriched_usage_result.failure?

            compare_fees(legacy_usage_result.usage.fees, enriched_usage_result.usage.fees)
            result
          ensure
            # Ensure the organization state is restored
            organization.reload
          end

          private

          attr_reader :subscription, :organization, :deduplicate

          def compute_usage(enriched:)
            usage_result = nil

            ActiveRecord::Base.transaction do
              if enriched
                organization.enable_feature_flag!(:enriched_events_aggregation)
                organization.update!(clickhouse_deduplication_enabled: deduplicate, pre_filter_events: true)
              else
                organization.disable_feature_flag!(:enriched_events_aggregation)
                organization.update!(clickhouse_deduplication_enabled: deduplicate)
              end
              organization.reload

              usage_result = Invoices::CustomerUsageService.call(
                customer: subscription.customer,
                subscription: subscription,
                with_cache: false,
                apply_taxes: false
              )

              raise ActiveRecord::Rollback
            end

            usage_result
          end

          def compare_fees(legacy_fees, enriched_fees)
            legacy_by_key = legacy_fees.index_by { |f| fee_key(f) }
            enriched_by_key = enriched_fees.index_by { |f| fee_key(f) }

            all_keys = (legacy_by_key.keys + enriched_by_key.keys).uniq
            diff_count = 0

            all_keys.each do |key|
              legacy_fee = legacy_by_key[key]
              enriched_fee = enriched_by_key[key]

              if legacy_fee && !enriched_fee
                diff_count += 1
                result.fee_details << build_detail(key, "only_in_legacy", legacy_fee, nil)
              elsif enriched_fee && !legacy_fee
                diff_count += 1
                result.fee_details << build_detail(key, "only_in_enriched", nil, enriched_fee)
              else
                diffs = compute_field_diffs(legacy_fee, enriched_fee)
                if diffs.any?
                  diff_count += 1
                  result.fee_details << build_detail(key, "diff", legacy_fee, enriched_fee, diffs:)
                else
                  result.fee_details << build_detail(key, "match", legacy_fee, enriched_fee)
                end
              end
            end

            result.diff_count = diff_count
          end

          def fee_key(fee)
            grouped = fee.grouped_by.presence || {}
            [fee.charge_id, fee.charge_filter_id, grouped]
          end

          def compute_field_diffs(legacy_fee, enriched_fee)
            {
              units: [legacy_fee.units, enriched_fee.units],
              amount_cents: [legacy_fee.amount_cents, enriched_fee.amount_cents],
              events_count: [legacy_fee.events_count, enriched_fee.events_count],
              total_aggregated_units: [legacy_fee.total_aggregated_units, enriched_fee.total_aggregated_units]
            }.select { |_, (legacy, enriched)| legacy != enriched }
          end

          def build_detail(key, status, legacy_fee, enriched_fee, diffs: {})
            fee = legacy_fee || enriched_fee

            FeeDetail.new(
              charge_id: key[0],
              charge_filter_id: key[1],
              grouped_by: key[2],
              billable_metric_code: fee.billable_metric.code,
              aggregation_type: fee.billable_metric.aggregation_type,
              charge_model: fee.charge.charge_model,
              from: fee.properties.dig("charges_from_datetime"),
              to: fee.properties.dig("charges_to_datetime"),
              status:,
              legacy: legacy_fee ? fee_values(legacy_fee) : nil,
              enriched: enriched_fee ? fee_values(enriched_fee) : nil,
              diffs: diffs.transform_values { |values| FieldDiff.new(legacy: values[0], enriched: values[1]) }
            )
          end

          def fee_values(fee)
            FeeValues.new(
              units: fee.units.to_s,
              amount_cents: fee.amount_cents,
              events_count: fee.events_count,
              total_aggregated_units: fee.total_aggregated_units.to_s
            )
          end
        end
      end
    end
  end
end
