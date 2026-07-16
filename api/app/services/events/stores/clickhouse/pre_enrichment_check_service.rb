# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      class PreEnrichmentCheckService < BaseService
        Result = BaseResult[:subscriptions_to_reprocess]

        # Initial release of the pre-enrichment pipeline
        RECURRING_BM_CUTOFF = Time.zone.parse("2025-11-25").freeze

        # Deploy of https://github.com/getlago/lago/pull/710
        PRICING_GROUP_KEYS_CUTOFF = Time.zone.parse("2026-03-06").freeze

        def initialize(organization:, reprocess: false, batch_size: 1000, sleep_seconds: 0.5)
          @organization = organization
          @reprocess = reprocess
          @batch_size = batch_size
          @sleep_seconds = sleep_seconds
          super
        end

        def call
          result.subscriptions_to_reprocess = {}
          return result if skip_organization?

          merge_results!(recurring_bm_subscriptions)
          merge_results!(pricing_group_key_subscriptions)
          merge_results!(new_charge_or_filters_subscriptions)

          reprocess_subscriptions! if reprocess

          result
        end

        private

        attr_reader :organization, :reprocess, :batch_size, :sleep_seconds

        def recurring_bm_subscriptions
          organization.subscriptions
            .joins(plan: {charges: :billable_metric})
            .where(billable_metrics: {recurring: true})
            .where("subscriptions.started_at < ?", RECURRING_BM_CUTOFF)
            .where(external_id: organization.subscriptions.active.select(:external_id))
            .group("subscriptions.id")
            .pluck("subscriptions.id", Arel.sql("ARRAY_AGG(DISTINCT billable_metrics.code)"))
        end

        def pricing_group_key_subscriptions
          organization.subscriptions.active
            .joins(plan: {charges: :billable_metric})
            .joins("LEFT JOIN charge_filters ON charge_filters.charge_id = charges.id")
            .where("COALESCE(charge_filters.properties, charges.properties) ? 'pricing_group_keys'")
            .where("subscriptions.started_at < ?", PRICING_GROUP_KEYS_CUTOFF)
            .where("charge_filters.deleted_at IS NULL")
            .group("subscriptions.id")
            .pluck("subscriptions.id", Arel.sql("ARRAY_AGG(DISTINCT billable_metrics.code)"))
        end

        def new_charge_or_filters_subscriptions
          organization.subscriptions.active
            .joins(plan: {charges: :billable_metric})
            .joins("LEFT JOIN charge_filters ON charge_filters.charge_id = charges.id")
            .where("COALESCE(charge_filters.created_at, charges.created_at) > subscriptions.started_at")
            .where("charge_filters.deleted_at IS NULL")
            .group("subscriptions.id")
            .pluck("subscriptions.id", Arel.sql("ARRAY_AGG(DISTINCT billable_metrics.code)"))
        end

        def merge_results!(query_results)
          query_results.each do |subscription_id, codes|
            result.subscriptions_to_reprocess[subscription_id] ||= []
            result.subscriptions_to_reprocess[subscription_id] |= codes
          end
        end

        def skip_organization?
          !recurring_bm_charges? && !pricing_group_key_charges? && !new_charges_or_filters?
        end

        def recurring_bm_charges?
          organization.plans
            .joins(charges: :billable_metric)
            .where(billable_metrics: {recurring: true})
            .exists?
        end

        def pricing_group_key_charges?
          organization.plans
            .joins(:charges)
            .joins("LEFT JOIN charge_filters ON charge_filters.charge_id = charges.id")
            .where("COALESCE(charge_filters.properties, charges.properties) ? 'pricing_group_keys'")
            .where("charge_filters.deleted_at IS NULL")
            .exists?
        end

        def new_charges_or_filters?
          organization.subscriptions.active
            .joins(plan: :charges)
            .joins("LEFT JOIN charge_filters ON charge_filters.charge_id = charges.id")
            .where("COALESCE(charge_filters.created_at, charges.created_at) > subscriptions.started_at")
            .where("charge_filters.deleted_at IS NULL")
            .exists?
        end

        def reprocess_subscriptions!
          result.subscriptions_to_reprocess.each do |subscription_id, codes|
            PreEnrichmentCheckJob.perform_later(subscription_id:, codes:, batch_size:, sleep_seconds:)
          end
        end
      end
    end
  end
end
