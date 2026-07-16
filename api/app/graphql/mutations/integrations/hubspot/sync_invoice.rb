# frozen_string_literal: true

module Mutations
  module Integrations
    module Hubspot
      class SyncInvoice < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "SyncHubspotInvoice"
        description "Sync hubspot integration invoice"

        input_object_class Types::Integrations::SyncHubspotInvoiceInput

        field :invoice_id, ID, null: true

        def resolve(**args)
          invoice = current_organization.invoices.find_by(id: args[:invoice_id])

          result = ::Integrations::Aggregator::Invoices::Hubspot::CreateService.call_async(invoice:)
          result.success? ? result.invoice_id : result_error(result)
          result
        end
      end
    end
  end
end
