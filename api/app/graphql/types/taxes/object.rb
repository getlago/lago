# frozen_string_literal: true

module Types
  module Taxes
    class Object < Types::BaseObject
      graphql_name "Tax"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType

      field :code, String, null: false
      field :description, String, null: true
      field :name, String, null: false
      field :rate, Float, null: false

      field :applied_to_organization, Boolean, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :add_ons_count, Integer, null: false, description: "Number of add ons using this tax"
      field :charges_count, Integer, null: false, description: "Number of charges using this tax"
      field :customers_count, Integer, null: false, description: "Number of customers using this tax"
      field :plans_count, Integer, null: false, description: "Number of plans using this tax"

      field :auto_generated, Boolean, null: false

      def add_ons_count
        object.add_ons.count
      end

      def charges_count
        object.charges.count
      end

      def plans_count
        object.plans.count
      end
    end
  end
end
