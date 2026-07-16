# frozen_string_literal: true

module Mutations
  module Invoices
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:create"

      graphql_name "CreateInvoice"
      description "Creates a new Invoice"

      input_object_class Types::Invoices::CreateInvoiceInput

      type Types::Invoices::Object

      def resolve(**args)
        customer = current_organization.customers.find_by(id: args[:customer_id])

        result = ::Invoices::CreateOneOffService.call(
          customer:,
          currency: args[:currency],
          fees: args[:fees],
          timestamp: Time.current.to_i,
          voided_invoice_id: args[:voided_invoice_id],
          payment_method_params: args[:payment_method]&.to_h,
          invoice_custom_section: args[:invoice_custom_section],
          billing_entity_id: args[:billing_entity_id],
          purchase_order_number: args[:purchase_order_number]
        )

        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
