# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class ExpireService < BaseService
      Result = BaseResult[:subscription]

      def initialize(subscription:)
        @subscription = subscription
        super
      end

      def call
        subscription.with_lock do
          # Race protection: a payment webhook may resolve the subscription
          # concurrently. If it already did so by the time we acquired the
          # lock, bail.
          next unless subscription.incomplete?

          payment_rule = subscription.activation_rules.payment.sole
          Payment::EvaluateService.call!(rule: payment_rule, status: :expired)

          invoice = subscription.invoices.open.subscription.sole
          invoice.closed!

          ResolveSubscriptionStatusService.call!(subscription:)
          subscription.update!(cancellation_reason: :timeout)

          enqueue_psp_cancel(invoice)
          enqueue_recredit_jobs(invoice)
        end

        result.subscription = subscription
        result
      end

      private

      attr_reader :subscription

      def enqueue_recredit_jobs(invoice)
        invoice.credits.coupon_kind.find_each do |credit|
          AppliedCoupons::RecreditJob.perform_after_commit(credit)
        end

        invoice.credits.credit_note_kind.find_each do |credit|
          CreditNotes::RecreditJob.perform_after_commit(credit)
        end

        invoice.wallet_transactions.outbound.find_each do |wallet_transaction|
          WalletTransactions::RecreditJob.perform_after_commit(wallet_transaction)
        end
      end

      def enqueue_psp_cancel(invoice)
        # A partial unique index on payments guarantees at most one
        # provider payment in (pending, processing) per invoice, and the
        # payment-gated lifecycle ensures the first failure already
        # cancels the subscription before any retry could create a second
        # one — so this find returns the single live payment when present.
        payment = invoice.payments
          .where(payable_payment_status: %w[pending processing])
          .first
        return unless payment

        PaymentProviders::CancelPaymentJob.perform_after_commit(payment)
      end
    end
  end
end
