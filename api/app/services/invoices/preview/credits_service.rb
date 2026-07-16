# frozen_string_literal: true

module Invoices
  module Preview
    class CreditsService < BaseService
      Result = BaseResult[:credits]

      def initialize(invoice:, terminated_subscription: nil)
        @invoice = invoice
        @terminated_subscription = terminated_subscription
        super
      end

      def call
        result.credits = credits_from_terminated_subscription + persisted_credits
        result
      end

      private

      attr_accessor :invoice, :terminated_subscription

      def persisted_credits
        Credits::CreditNoteService
          .call!(invoice:, context: :preview)
          .credits
      end

      def credits_from_terminated_subscription
        return [] unless terminated_subscription&.plan&.pay_in_advance?

        credit_note = generate_credit_note
        return [] unless credit_note

        credit_amount = [credit_note.balance_amount_cents, invoice.total_amount_cents].min
        return [] unless credit_amount.positive?

        credit = Credit.new(
          invoice:,
          organization_id: invoice.organization_id,
          credit_note:,
          amount_cents: credit_amount,
          amount_currency: invoice.currency,
          before_taxes: false
        )

        invoice.credit_notes_amount_cents += credit.amount_cents
        [credit]
      end

      def generate_credit_note
        return unless terminated_subscription.plan.pay_in_advance?

        CreditNotes::CreateFromTermination.call!(
          subscription: terminated_subscription,
          reason: "order_cancellation",
          upgrade: terminated_subscription.upgraded?,
          context: :preview
        ).credit_note
      end
    end
  end
end
