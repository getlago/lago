# frozen_string_literal: true

module Commitments
  class FetchInvoicesService < BaseService
    def self.new_instance(commitment:, invoice_subscription:)
      klass = if invoice_subscription.subscription.plan.pay_in_advance?
        Commitments::Minimum::InAdvance::FetchInvoicesService
      else
        Commitments::Minimum::InArrears::FetchInvoicesService
      end

      klass.new(commitment:, invoice_subscription:)
    end

    def initialize(commitment:, invoice_subscription:)
      @commitment = commitment
      @invoice_subscription = invoice_subscription

      super
    end

    def call
      result.invoices = fetch_invoices
      result
    end

    private

    attr_reader :commitment, :invoice_subscription

    delegate :subscription, to: :invoice_subscription
    delegate :plan, to: :subscription
  end
end
