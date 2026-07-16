# frozen_string_literal: true

module Invoices
  class RefreshDraftAndFinalizeService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:)
      @invoice = invoice
      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") if invoice.nil?
      return result.forbidden_failure! unless invoice.subscription?

      return result unless invoice.draft?
      return result.forbidden_failure!(code: "cannot_finalize_with_pending_taxes") if invoice.tax_pending?
      drafted_issuing_date = invoice.issuing_date

      ActiveRecord::Base.transaction do
        invoice.issuing_date = issuing_date
        refresh_result = Invoices::RefreshDraftService.call(invoice:, context: :finalize)
        if invoice.tax_pending?
          # When we need to fetch taxes, the invoice isn't finalized until taxes are pulled.
          # So we can't show the final issuing/payment due dates yet.
          # We'll set those in Inovoices::ProviderTaxes::PullTaxesAndApplyService
          # once the taxes are successfully pulled.
          invoice.update!(issuing_date: drafted_issuing_date)
          # rubocop:disable Rails/TransactionExitStatement
          return refresh_result
          # rubocop:enable Rails/TransactionExitStatement
        end
        refresh_result.raise_if_error!

        invoice.payment_due_date = payment_due_date
        Invoices::TransitionToFinalStatusService.call(invoice:)
        invoice.save!

        invoice.credit_notes.each(&:finalized!)
      end

      result.invoice = invoice.reload
      after_commit do
        clear_invoice_generation_errors(invoice)
        unless invoice.closed?
          SendWebhookJob.perform_later("invoice.created", invoice)
          Utils::ActivityLog.produce(invoice, "invoice.created")
          GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
          Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
          Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
          Invoices::Payments::CreateService.call_async(invoice:)
          Utils::SegmentTrack.invoice_created(invoice)
        end

        invoice.credit_notes.each do |credit_note|
          track_credit_note_created(credit_note)
          SendWebhookJob.perform_later("credit_note.created", credit_note)
          Utils::ActivityLog.produce(credit_note, "credit_note.created")
          CreditNotes::GenerateDocumentsJob.perform_later(credit_note)
        end
      end

      result
    end

    private

    attr_accessor :invoice, :result

    def issuing_date
      @issuing_date ||=
        if issuing_date_keep_anchor?
          invoice.issuing_date
        else
          Time.current.in_time_zone(invoice.customer.applicable_timezone).to_date
        end
    end

    def issuing_date_keep_anchor?
      invoice.invoice_subscriptions.first&.recurring? &&
        invoice.customer.applicable_subscription_invoice_issuing_date_adjustment == "keep_anchor"
    end

    def payment_due_date
      @payment_due_date ||= issuing_date + invoice.customer.applicable_net_payment_term.days
    end

    def track_credit_note_created(credit_note)
      SegmentTrackJob.perform_later(
        membership_id: CurrentContext.membership,
        event: "credit_note_issued",
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          invoice_id: credit_note.invoice_id,
          credit_note_method: "credit"
        }
      )
    end

    def should_deliver_email?
      License.premium? &&
        invoice.billing_entity.email_settings.include?("invoice.finalized")
    end

    def clear_invoice_generation_errors(invoice)
      invoice_error = invoice.error_details.invoice_generation_error.last
      return if invoice_error.blank?

      delete_generating_sequence_number_error(invoice_error)
    end

    def delete_generating_sequence_number_error(invoice_error)
      backtrace = invoice_error.details["backtrace"]&.first || ""
      return unless backtrace.include?("generate_organization_sequential_id") || backtrace.include?("generate_billing_entity_sequential_id")

      invoice_error.delete
    end
  end
end
