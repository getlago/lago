# frozen_string_literal: true

module Commitments
  class DatesService < BaseService
    Result = BaseResult

    def self.new_instance(commitment:, invoice_subscription:)
      klass = if invoice_subscription.subscription.plan.pay_in_advance?
        Commitments::Minimum::InAdvance::DatesService
      else
        Commitments::Minimum::InArrears::DatesService
      end

      klass.new(commitment:, invoice_subscription:)
    end

    def initialize(commitment:, invoice_subscription:)
      @commitment = commitment
      @invoice_subscription = invoice_subscription

      super
    end

    def call
      ds = Subscriptions::DatesService.new_instance(
        invoice_subscription.subscription,
        invoice_subscription.timestamp,
        current_usage:
      )

      return ds unless invoice_subscription.subscription.terminated?

      Subscriptions::TerminatedDatesService.new(
        subscription: invoice_subscription.subscription,
        invoice: invoice_subscription.invoice,
        date_service: ds,
        match_invoice_subscription: invoice_subscription.subscription.plan.pay_in_advance?
      ).call
    end

    private

    attr_reader :commitment, :invoice_subscription
  end
end
