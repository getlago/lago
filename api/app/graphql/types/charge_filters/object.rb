# frozen_string_literal: true

module Types
  module ChargeFilters
    class Object < Types::BaseObject
      graphql_name "ChargeFilter"
      description "Charge filters object"

      field :charge_code, String, null: true
      field :id, ID, null: false

      field :invoice_display_name, String, null: true
      field :properties, Types::Charges::Properties, null: false
      field :values, Types::ChargeFilters::Values, null: false, method: :to_h

      def charge_code
        object.charge&.code
      end
    end
  end
end
