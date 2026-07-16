# frozen_string_literal: true

module BillingEntities
  class ChangeInvoiceNumberingService < BaseService
    Result = BaseResult[:billing_entity]

    def initialize(billing_entity:, document_numbering:)
      @billing_entity = billing_entity
      @document_numbering = document_numbering
      super
    end

    def call
      result.billing_entity = billing_entity
      billing_entity.document_numbering = document_numbering

      return result unless billing_entity.document_numbering_changed?

      if billing_entity.per_billing_entity? && last_invoice
        last_invoice.update!(billing_entity_sequential_id: billing_entity_invoices_count)
      end

      result
    end

    private

    attr_reader :billing_entity, :document_numbering

    def last_invoice
      @last_invoice ||= billing_entity
        .invoices
        .non_self_billed
        .with_generated_number
        .order(created_at: :desc)
        .where(billing_entity_sequential_id: nil)
        .first
    end

    def billing_entity_invoices_count
      billing_entity.invoices.non_self_billed.with_generated_number.count
    end
  end
end
