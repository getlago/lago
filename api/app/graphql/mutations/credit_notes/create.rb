# frozen_string_literal: true

module Mutations
  module CreditNotes
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "credit_notes:create"

      graphql_name "CreateCreditNote"
      description "Creates a new Credit Note"

      argument :description, String, required: false
      argument :invoice_id, ID, required: true
      argument :reason, Types::CreditNotes::ReasonTypeEnum, required: true

      argument :credit_amount_cents, GraphQL::Types::BigInt, required: false
      argument :offset_amount_cents, GraphQL::Types::BigInt, required: false
      argument :refund_amount_cents, GraphQL::Types::BigInt, required: false

      argument :items, [Types::CreditNoteItems::Input], required: true
      argument :metadata, [Types::Metadata::Input], required: false, **Types::Metadata::Input::ARGUMENT_OPTIONS

      type Types::CreditNotes::Object

      def resolve(**args)
        args[:items].map!(&:to_h)

        result = ::CreditNotes::CreateService
          .call(
            invoice: current_organization.invoices.visible.find_by(id: args[:invoice_id]),
            **args
          )

        result.success? ? result.credit_note : result_error(result)
      end
    end
  end
end
