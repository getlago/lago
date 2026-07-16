# frozen_string_literal: true

module Types
  module Charges
    class PresentationGroupKeyInput < Types::BaseInputObject
      argument :options, Types::Charges::PresentationGroupKeyOptionsInput, required: false
      argument :value, String, required: true
    end
  end
end
