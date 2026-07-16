# frozen_string_literal: true

module Customers
  class TerminateRelationsService < BaseService
    Result = BaseResult[:customer]

    def initialize(customer:)
      @customer = customer
      super
    end

    def call
      return result.not_found_failure!(resource: "customer") unless customer

      # NOTE: Terminate active subscriptions.
      customer.subscriptions.active.find_each do |subscription|
        Subscriptions::TerminateService.call(subscription:, async: false)
      end

      # NOTE: Cancel pending subscriptions
      customer.subscriptions.pending.find_each(&:mark_as_canceled!)

      # NOTE: Finalize all draft invoices.
      customer.invoices.draft.find_each { |invoice| Invoices::FinalizeJob.set(wait: 5.minutes).perform_later(invoice) }

      # NOTE: Terminate applied coupons
      customer.applied_coupons.active.find_each do |applied_coupon|
        AppliedCoupons::TerminateService.call(applied_coupon:)
      end

      # NOTE: Terminate wallets
      customer.wallets.active.find_each { |wallet| Wallets::TerminateService.call(wallet:) }

      result.customer = customer
      result
    end

    private

    attr_reader :customer
  end
end
