# frozen_string_literal: true

module Resolvers
  class InvoiceCreditNotesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "credit_notes:view"

    description "Query invoice's credit note"

    argument :invoice_id, ID, required: true, description: "Uniq ID of the invoice"
    argument :limit, Integer, required: false
    argument :page, Integer, required: false

    type Types::CreditNotes::Object.collection_type, null: true

    def resolve(invoice_id: nil, page: nil, limit: nil)
      current_organization
        .invoices
        .find(invoice_id)
        .credit_notes
        .finalized
        .order(created_at: :desc)
        .page(page)
        .per(limit)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "invoice")
    end
  end
end
