# frozen_string_literal: true

module Invoices
  class UpdateIssuingDateFromBillingEntityService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:, previous_issuing_date_settings:)
      @invoice = invoice
      @previous_issuing_date_settings = previous_issuing_date_settings
      super
    end

    def call
      result.invoice = invoice
      return result unless invoice.draft?

      invoice.issuing_date = invoice.issuing_date + issuing_date_adjustment.days
      invoice.expected_finalization_date = invoice.expected_finalization_date + grace_period_adjustment
      invoice.applied_grace_period = invoice.customer.applicable_invoice_grace_period
      invoice.payment_due_date = invoice.issuing_date + invoice.customer.applicable_net_payment_term.days
      invoice.save!

      result
    end

    private

    attr_reader :invoice, :previous_issuing_date_settings

    def issuing_date_adjustment
      new_issuing_date_adjustment = new_issuing_date_service.issuing_date_adjustment
      old_issuing_date_adjustment = old_issuing_date_service.issuing_date_adjustment

      new_issuing_date_adjustment - old_issuing_date_adjustment
    end

    def grace_period_adjustment
      new_grace_period = new_issuing_date_service.grace_period
      old_grace_period = old_issuing_date_service.grace_period

      new_grace_period - old_grace_period
    end

    def old_issuing_date_service
      Invoices::IssuingDateService.new(
        customer_settings: invoice.customer,
        billing_entity_settings: previous_issuing_date_settings,
        recurring:
      )
    end

    def new_issuing_date_service
      Invoices::IssuingDateService.new(
        customer_settings: invoice.customer,
        billing_entity_settings: invoice.billing_entity,
        recurring:
      )
    end

    def recurring
      invoice.invoice_subscriptions.first&.recurring?
    end
  end
end
