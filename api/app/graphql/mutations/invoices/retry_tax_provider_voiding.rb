# frozen_string_literal: true

module Mutations
  module Invoices
    class RetryTaxProviderVoiding < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      description "Retry voided invoice sync"

      argument :id, ID, required: true

      type Types::Invoices::Object

      def resolve(**args)
        invoice = current_organization.invoices.visible.find_by(id: args[:id])
        result = ::Invoices::ProviderTaxes::VoidService.call(invoice:)

        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
