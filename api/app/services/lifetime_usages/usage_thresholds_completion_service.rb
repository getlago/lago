# frozen_string_literal: true

module LifetimeUsages
  class UsageThresholdsCompletionService < BaseService
    Result = BaseResult[:usage_thresholds]

    def initialize(lifetime_usage:)
      @lifetime_usage = lifetime_usage
      @usage_thresholds = lifetime_usage.subscription.applicable_usage_thresholds

      super
    end

    def call
      result.usage_thresholds = []
      return result unless usage_thresholds.any?

      largest_non_recurring_threshold_amount_cents = usage_thresholds.not_recurring.order(amount_cents: :desc).first&.amount_cents || 0
      recurring_threshold = usage_thresholds.recurring.first

      # split non-recurring thresholds into 2 groups: passed and not passed
      passed_thresholds, not_passed_thresholds = usage_thresholds.not_recurring.order(amount_cents: :asc).partition do |threshold|
        threshold.amount_cents <= lifetime_usage.total_amount_cents
      end

      subscription_ids = organization.subscriptions
        .where(external_id: subscription.external_id, subscription_at: subscription.subscription_at)
        .where(canceled_at: nil)
        .ids

      # add all passed thresholds to the result, completion rate is 100%
      passed_thresholds.each do |threshold|
        # fallback to Time.current if the invoice is not yet generated
        reached_at = AppliedUsageThreshold
          .where(usage_threshold: threshold)
          .joins(invoice: :invoice_subscriptions)
          .where(invoice_subscriptions: {subscription_id: subscription_ids}).maximum(:created_at) || Time.current

        add_usage_threshold threshold, threshold.amount_cents, 1.0, reached_at
      end

      last_passed_threshold_amount = passed_thresholds.last&.amount_cents || 0

      # If we have a not-passed threshold that means we can ignore the recurring one
      # if not_passed_thresholds is empty, we need to check the recurring one.
      if not_passed_thresholds.empty?
        if recurring_threshold
          add_recurring_threshold(recurring_threshold, last_passed_threshold_amount, subscription_ids)
        end
      else
        threshold = not_passed_thresholds.shift
        add_usage_threshold threshold, threshold.amount_cents, (lifetime_usage.total_amount_cents - last_passed_threshold_amount).fdiv(threshold.amount_cents - last_passed_threshold_amount), nil

        not_passed_thresholds.each do |threshold|
          add_usage_threshold threshold, threshold.amount_cents, 0.0, nil
        end

        # add recurring at the end if it's there
        if recurring_threshold
          add_usage_threshold recurring_threshold, largest_non_recurring_threshold_amount_cents + recurring_threshold.amount_cents, 0.0, nil
        end
      end

      result
    end

    private

    attr_reader :lifetime_usage, :usage_thresholds
    delegate :organization, :subscription, to: :lifetime_usage

    def add_usage_threshold(usage_threshold, amount_cents, completion_ratio, reached_at)
      result.usage_thresholds << {
        usage_threshold:,
        amount_cents:,
        completion_ratio:,
        reached_at:
      }
    end

    def add_recurring_threshold(recurring_threshold, last_passed_threshold_amount, subscription_ids)
      recurring_remainder = (last_passed_threshold_amount + lifetime_usage.total_amount_cents) % recurring_threshold.amount_cents

      applied_thresholds = AppliedUsageThreshold
        .where(usage_threshold: recurring_threshold)
        .joins(invoice: :invoice_subscriptions)
        .where(invoice_subscriptions: {subscription_id: subscription_ids})
        .order(lifetime_usage_amount_cents: :asc)

      occurence = (lifetime_usage.total_amount_cents - last_passed_threshold_amount) / recurring_threshold.amount_cents
      occurence.times do |i|
        amount_cents = last_passed_threshold_amount + ((i + 1) * recurring_threshold.amount_cents)
        reached_at = applied_thresholds.find { |applied| applied.lifetime_usage_amount_cents >= amount_cents }&.created_at || Time.current

        add_usage_threshold recurring_threshold, amount_cents, 1.0, reached_at
      end
      add_usage_threshold recurring_threshold, lifetime_usage.total_amount_cents - recurring_remainder + recurring_threshold.amount_cents, recurring_remainder.fdiv(recurring_threshold.amount_cents), nil
    end
  end
end
