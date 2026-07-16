# frozen_string_literal: true

module Types
  module Emails
    class ResendEmailInput < Types::BaseInputObject
      description "Resend email input arguments"

      argument :bcc, [String], required: false, description: "BCC recipients"
      argument :cc, [String], required: false, description: "CC recipients"
      argument :id, ID, required: true, description: "Document ID"
      argument :to, [String], required: false, description: "Custom recipients (defaults to customer email)"
    end
  end
end
