# frozen_string_literal: true

module Types
  module Charges
    class PresentationGroupKeyOptionsInput < Types::BaseInputObject
      argument :display_in_invoice, Boolean, required: false
    end
  end
end
