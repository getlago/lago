# frozen_string_literal: true

module Resolvers
  class InvoiceCustomSectionResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query a single invoice_custom_section of an organization"

    argument :id, ID, required: true, description: "Uniq ID of the invoice_custom_section"

    type Types::InvoiceCustomSections::Object, null: false

    def resolve(id: nil)
      current_organization.invoice_custom_sections.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "invoice_custom_section")
    end
  end
end
