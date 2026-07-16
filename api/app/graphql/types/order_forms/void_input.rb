# frozen_string_literal: true

module Types
  module OrderForms
    class VoidInput < Types::BaseInputObject
      description "Void Order Form input arguments"

      argument :id, ID, required: true
    end
  end
end
