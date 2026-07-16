# frozen_string_literal: true

module Types
  module FixedCharges
    class Object < Types::BaseObject
      graphql_name "FixedCharge"

      field :code, String, null: true
      field :id, ID, null: false
      field :invoice_display_name, String, null: true
      field :parent_id, ID, null: true

      field :add_on, Types::AddOns::Object, null: false
      field :charge_model, Types::FixedCharges::ChargeModelEnum, null: false
      field :pay_in_advance, Boolean, null: false
      field :properties, Types::FixedCharges::Properties, null: true
      field :prorated, Boolean, null: false
      field :units, String, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :taxes, [Types::Taxes::Object]

      def properties
        return object.properties unless object.properties == "{}"

        JSON.parse(object.properties)
      end

      def units
        # Remove decimal part when it is zero (e.g., "1.0" becomes "1")
        value = object.units.to_f
        (value == value.to_i) ? value.to_i.to_s : value.to_s
      end

      def add_on
        AddOn.with_discarded.find_by(id: object.add_on_id)
      end
    end
  end
end
