# frozen_string_literal: true

module Mutations
  module Integrations
    class SyncInvoice < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "SyncIntegrationInvoice"
      description "Sync integration invoice"

      input_object_class Types::Integrations::SyncInvoiceInput

      field :invoice_id, ID, null: true

      def resolve(**args)
        invoice = current_organization.invoices.find_by(id: args[:invoice_id])

        result = ::Integrations::Aggregator::Invoices::CreateService.call_async(invoice:, find_first: true)
        result.success? ? result.invoice_id : result_error(result)
        result
      end
    end
  end
end
