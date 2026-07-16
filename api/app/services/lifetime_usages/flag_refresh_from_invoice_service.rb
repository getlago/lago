# frozen_string_literal: true

module LifetimeUsages
  class FlagRefreshFromInvoiceService < BaseService
    Result = BaseResult[:lifetime_usages]

    def initialize(invoice:)
      @invoice = invoice
      super
    end

    def call
      return result unless invoice.subscription?
      return result unless should_flag_refresh_from_invoice?

      result.lifetime_usages = []

      invoice.subscriptions.each do |subscription|
        lifetime_usage = subscription.lifetime_usage
        lifetime_usage ||= subscription.build_lifetime_usage(organization: subscription.organization)
        lifetime_usage.recalculate_invoiced_usage = true
        lifetime_usage.save!

        result.lifetime_usages << lifetime_usage
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice

    def should_flag_refresh_from_invoice?
      invoice.organization.lifetime_usage_enabled? || invoice.subscriptions.any?(&:has_progressive_billing?)
    end
  end
end
