# frozen_string_literal: true

module Types
  module Orders
    class Object < Types::BaseObject
      graphql_name "Order"

      field :execution_mode, Types::Orders::ExecutionModeEnum, null: true
      field :id, ID, null: false
      field :number, String, null: false
      field :order_type, Quotes::OrderTypeEnum, null: false
      field :status, Types::Orders::StatusEnum, null: false

      field :billing_snapshot, GraphQL::Types::JSON, null: false
      field :currency, String, null: true
      field :execute_at, GraphQL::Types::ISO8601DateTime, null: true
      field :executed_at, GraphQL::Types::ISO8601DateTime, null: true

      field :customer, Types::Customers::Object, null: false
      field :order_form, Types::OrderForms::Object, null: false
      field :organization, Types::Organizations::OrganizationType, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      dataload_association :customer
      dataload_association :order_form
      dataload_association :organization
    end
  end
end
