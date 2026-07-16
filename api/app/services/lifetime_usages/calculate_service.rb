# frozen_string_literal: true

module LifetimeUsages
  class CalculateService < BaseService
    Result = BaseResult[:lifetime_usage]

    def initialize(lifetime_usage:, current_usage: nil)
      @lifetime_usage = lifetime_usage
      @current_usage = current_usage
      super
    end

    def call
      result.lifetime_usage = lifetime_usage

      # clear boolean flags without recalculating if the subscription is not active.
      if !lifetime_usage.subscription.active?
        lifetime_usage.update!(recalculate_current_usage: false, recalculate_invoiced_usage: false)
        return result
      end

      if lifetime_usage.recalculate_invoiced_usage
        lifetime_usage.invoiced_usage_amount_cents = calculate_invoiced_usage_amount_cents
        lifetime_usage.recalculate_invoiced_usage = false
        lifetime_usage.invoiced_usage_amount_refreshed_at = Time.current
      end

      lifetime_usage.current_usage_amount_cents = calculate_current_usage_amount_cents
      lifetime_usage.recalculate_current_usage = false
      lifetime_usage.current_usage_amount_refreshed_at = Time.current

      lifetime_usage.save!

      result
    end

    private

    delegate :subscription, :organization, to: :lifetime_usage

    def calculate_invoiced_usage_amount_cents
      subscription_ids = organization.subscriptions
        .where(external_id: subscription.external_id, subscription_at: subscription.subscription_at)
        .where(canceled_at: nil)
        .select(:id)

      invoices = organization.invoices.subscription
        .where(status: %i[finalized draft])
        .joins(:invoice_subscriptions)
        .where(invoice_subscriptions: {subscription_id: subscription_ids})
      invoices.sum { |invoice| invoice.fees.charge.sum(:amount_cents) }
    end

    def calculate_current_usage_amount_cents
      current_usage.amount_cents
    end

    def current_usage
      @current_usage ||= Invoices::CustomerUsageService.call(
        customer: subscription.customer,
        subscription: subscription,
        apply_taxes: false
      ).usage
    end

    attr_accessor :lifetime_usage
  end
end
