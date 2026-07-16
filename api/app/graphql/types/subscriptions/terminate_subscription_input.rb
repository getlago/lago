# frozen_string_literal: true

module Types
  module Subscriptions
    class TerminateSubscriptionInput < Types::BaseInputObject
      description "Input for terminating a subscription"

      argument :id, ID, required: true
      argument :on_termination_credit_note, Types::Subscriptions::OnTerminationCreditNoteEnum, required: false
      argument :on_termination_invoice, Types::Subscriptions::OnTerminationInvoiceEnum, required: false
    end
  end
end
