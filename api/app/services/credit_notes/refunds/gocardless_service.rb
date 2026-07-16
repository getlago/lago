# frozen_string_literal: true

module CreditNotes
  module Refunds
    class GocardlessService < BaseService
      include Customers::PaymentProviderFinder

      PENDING_STATUSES = %w[created pending_submission submitted refund_settled].freeze
      SUCCESS_STATUSES = %w[paid].freeze
      FAILED_STATUSES = %w[cancelled bounced funds_returned failed].freeze

      def initialize(credit_note = nil)
        @credit_note = credit_note

        super
      end

      def create
        result.credit_note = credit_note
        return result unless should_process_refund?

        gocardless_result = create_gocardless_refund

        refund = Refund.new(
          organization_id: credit_note.organization_id,
          credit_note:,
          refundable: credit_note,
          reason: :credit_note,
          payment:,
          payment_provider: payment.payment_provider,
          payment_provider_customer: payment_provider_customer(customer),
          amount_cents: gocardless_result.amount,
          amount_currency: gocardless_result.currency&.upcase,
          status: gocardless_result.status,
          provider_refund_id: gocardless_result.id
        )
        refund.save!

        update_credit_note_status(credit_note_status(refund.status))
        Utils::SegmentTrack.refund_status_changed(refund.status, credit_note.id, organization.id)

        result.refund = refund
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue GoCardlessPro::Error, GoCardlessPro::ValidationError => e
        deliver_error_webhook(message: e.message, code: e.code)
        update_credit_note_status(:failed)
        Utils::ActivityLog.produce(credit_note, "credit_note.refund_failure")

        if e.is_a?(GoCardlessPro::ValidationError)
          result
        else
          raise
        end
      end

      def update_status(provider_refund_id:, status:, metadata: {})
        refund = Refund.find_by(provider_refund_id:)
        return handle_missing_refund(metadata) unless refund

        result.refund = refund
        @credit_note = result.credit_note = refund.credit_note
        return result if refund.credit_note.succeeded?

        refund.update!(status:)
        update_credit_note_status(credit_note_status(refund.status))
        Utils::SegmentTrack.refund_status_changed(refund.status, credit_note.id, organization.id)

        if FAILED_STATUSES.include?(status.to_s)
          deliver_error_webhook(message: "Payment refund failed", code: nil)
          Utils::ActivityLog.produce(credit_note, "credit_note.refund_failure")
          result.service_failure!(code: "refund_failed", message: "Refund failed to perform")
        end

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_accessor :credit_note

      delegate :organization, :customer, :invoice, to: :credit_note

      def should_process_refund?
        return false if !credit_note.refunded? || credit_note.succeeded? || invoice.payment_dispute_lost_at?

        payment.present?
      end

      def payment
        @payment ||= credit_note.invoice.payments.order(created_at: :desc).first
      end

      def client
        @client ||= GoCardlessPro::Client.new(
          access_token: gocardless_payment_provider.access_token,
          environment: gocardless_payment_provider.environment
        )
      end

      def gocardless_payment_provider
        @gocardless_payment_provider ||= payment_provider(customer)
      end

      def create_gocardless_refund
        # NOTE: Gocarless API accepts only 3 keys at max in metadata
        #       See https://developer.gocardless.com/api-reference#refunds-create-a-refund
        #       for reference
        client.refunds.create(
          params: {
            amount: credit_note.refund_amount_cents,
            total_amount_confirmation: credit_note.refund_amount_cents,
            links: {payment: payment.provider_payment_id},
            metadata: {
              lago_credit_note_id: credit_note.id,
              lago_invoice_id: invoice.id,
              reason: credit_note.reason.to_s
            }
          },
          headers: {
            "Idempotency-Key" => credit_note.id
          }
        )
      end

      def deliver_error_webhook(message:, code:)
        SendWebhookJob.perform_later(
          "credit_note.provider_refund_failure",
          credit_note,
          provider_customer_id: payment_provider_customer(customer)&.provider_customer_id,
          provider_error: {
            message:,
            error_code: code
          }
        )
      end

      def update_credit_note_status(status)
        credit_note.refund_status = status
        credit_note.refunded_at = Time.current if credit_note.succeeded?

        credit_note.save!
      end

      def credit_note_status(status)
        return "pending" if PENDING_STATUSES.include?(status)
        return "succeeded" if SUCCESS_STATUSES.include?(status)
        return "failed" if FAILED_STATUSES.include?(status)

        status
      end

      def handle_missing_refund(metadata)
        # NOTE: Refund was not initiated by lago
        return result unless metadata&.key?(:lago_invoice_id)

        # NOTE: Invoice does not belongs to this lago instance
        return result unless Invoice.find_by(id: metadata[:lago_invoice_id])

        result.not_found_failure!(resource: "gocardless_refund")
      end
    end
  end
end
