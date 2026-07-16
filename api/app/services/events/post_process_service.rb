# frozen_string_literal: true

module Events
  class PostProcessService < BaseService
    Result = BaseResult[:event]

    def initialize(event:)
      @organization = event.organization
      @event = event
      super
    end

    def call
      expire_cached_charges
      create_enriched_events
      track_subscription_activity
      customer&.flag_wallets_for_refresh
      # TODO: update also event-processor to process targeted wallets
      check_targeted_wallets

      handle_pay_in_advance

      result.event = event
      result
    rescue ActiveRecord::RecordNotUnique
      deliver_error_webhook(error: {transaction_id: ["value_already_exist"]})

      result
    end

    private

    attr_reader :event

    delegate :organization, to: :event

    def customer
      @customer ||= subscriptions.first&.customer
    end

    def subscriptions
      return @subscriptions if defined? @subscriptions

      subscriptions = organization.subscriptions
        .where(external_id: event.external_subscription_id)
        .where.not(status: :incomplete)
      return unless subscriptions

      @subscriptions = subscriptions
        .where("date_trunc('millisecond', started_at::timestamp) <= ?::timestamp", event.timestamp)
        .where(
          "terminated_at IS NULL OR date_trunc('millisecond', terminated_at::timestamp) >= ?",
          event.timestamp
        )
        .order("terminated_at DESC NULLS FIRST, started_at DESC")
    end

    def active_subscription
      @active_subscription ||= begin
        subs = subscriptions.select(&:active?)
        raise "Multiple active subscriptions found" if subs.length > 1
        subs.first
      end
    end

    def billable_metric
      @billable_metric ||= organization.billable_metrics.find_by(code: event.code)
    end

    def expire_cached_charges
      return if active_subscription.nil?
      return unless billable_metric

      charges_and_filters.each do |charge, filter|
        Subscriptions::ChargeCacheService.expire_cache(subscription: active_subscription, charge:, charge_filter: filter)
      end
    end

    def create_enriched_events
      return unless organization.feature_flag_enabled?(:postgres_enriched_events)
      return if active_subscription.nil?
      return unless billable_metric

      Events::EnrichService.call!(event:, subscription: active_subscription, billable_metric:, charges_and_filters:)
    end

    def track_subscription_activity
      # NOTE: We don't eager load usage_thresholds or alerts here so it could be considered an N+1 query
      #       But there should be only one active subscription here, so it's better to not re-requery to eager load
      subscriptions.select(&:active?).each do |subscription|
        date = Time.current.in_time_zone(customer.applicable_timezone).to_date
        UsageMonitoring::TrackSubscriptionActivityService.call(organization:, subscription:, date:)
      end
    end

    def check_targeted_wallets
      return unless organization.events_targeting_wallets_enabled?
      return if event.properties["target_wallet_code"].blank?
      return unless subscriptions
      return unless Charge.where(organization_id: event.organization_id, plan_id: subscriptions.map(&:plan_id),
        billable_metric:, accepts_target_wallet: true).exists?
      return if customer.wallets.active.where(code: event.properties["target_wallet_code"]).exists?

      SendWebhookJob.perform_later(
        "event.error",
        event,
        {error: {target_wallet_code: ["target_wallet_code_not_found"]}}
      )
    end

    def handle_pay_in_advance
      return unless billable_metric
      return unless charges.any?

      Events::PayInAdvanceJob.perform_later(Events::CommonFactory.new_instance(source: event).as_json)
    end

    def charges
      return Charge.none unless subscriptions.first

      subscriptions
        .first
        .plan
        .charges
        .pay_in_advance
        .joins(:billable_metric)
        .where(billable_metric: {code: event.code})
    end

    def deliver_error_webhook(error:)
      SendWebhookJob.perform_later("event.error", event, {error:})
    end

    def charges_and_filters
      return @charges_and_filters if @charges_and_filters.present?

      charges = billable_metric.charges
        .joins(:plan)
        .where(plans: {id: active_subscription&.plan_id})
        .includes(filters: {values: :billable_metric_filter})

      @charges_and_filters = charges
        .index_with { |c| ChargeFilters::EventMatchingService.call(charge: c, event:).charge_filter }
    end
  end
end
