# frozen_string_literal: true

module Types
  module CreditNotes
    class UpdateCreditNoteInput < BaseInputObject
      description "Update Credit Note input arguments"

      argument :id, ID, required: true
      argument :metadata, [Types::Metadata::Input], required: false, **Types::Metadata::Input::ARGUMENT_OPTIONS
      argument :refund_status, Types::CreditNotes::RefundStatusTypeEnum, required: false
    end
  end
end
