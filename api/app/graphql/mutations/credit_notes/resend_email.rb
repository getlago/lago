# frozen_string_literal: true

module Mutations
  module CreditNotes
    class ResendEmail < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "credit_notes:send"

      graphql_name "ResendCreditNoteEmail"
      description "Resend credit note email with optional custom recipients"

      input_object_class Types::Emails::ResendEmailInput

      type Types::CreditNotes::Object

      def resolve(**args)
        credit_note = current_organization.credit_notes.finalized.find_by(id: args[:id])

        result = ::Emails::ResendService.call(
          resource: credit_note,
          to: args[:to],
          cc: args[:cc],
          bcc: args[:bcc]
        )

        result.success? ? credit_note : result_error(result)
      end
    end
  end
end
