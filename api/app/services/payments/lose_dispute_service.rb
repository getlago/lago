# frozen_string_literal: true

module Payments
  class LoseDisputeService < BaseService
    Result = BaseResult[:invoices, :payment]

    def initialize(payment:, payment_dispute_lost_at: nil, reason: nil)
      @payment = payment
      @payable = payment&.payable
      @payment_dispute_lost_at = payment_dispute_lost_at.presence || Time.current
      @reason = reason
      super
    end

    def call
      return result.not_found_failure!(resource: "payment") if payment.nil?
      return result.not_found_failure!(resource: "payable") if payable.nil?

      result.payment = payment
      invoices = payment.invoices

      ActiveRecord::Base.transaction do
        invoices.each do |invoice|
          invoice.mark_as_dispute_lost!(payment_dispute_lost_at)

          after_commit do
            SendWebhookJob.perform_later("invoice.payment_dispute_lost", invoice, provider_error: reason)
            Invoices::ProviderTaxes::VoidJob.perform_later(invoice:)
            if invoice.should_update_hubspot_invoice?
              Integrations::Aggregator::Invoices::Hubspot::UpdateJob.perform_later(invoice:)
            end
          end
        end
      end

      result.invoices = invoices
      result
    rescue ActiveRecord::RecordInvalid => _e
      result.not_allowed_failure!(code: "not_disputable")
    end

    private

    attr_reader :payment, :payable, :payment_dispute_lost_at, :reason
  end
end
