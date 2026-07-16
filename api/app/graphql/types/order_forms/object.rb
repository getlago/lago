# frozen_string_literal: true

module Types
  module OrderForms
    class Object < Types::BaseObject
      graphql_name "OrderForm"

      field :id, ID, null: false
      field :number, String, null: false
      field :status, Types::OrderForms::StatusEnum, null: false
      field :void_reason, Types::OrderForms::VoidReasonEnum, null: true

      field :billing_snapshot, GraphQL::Types::JSON, null: false
      field :expires_at, GraphQL::Types::ISO8601DateTime, null: true
      field :signed_at, GraphQL::Types::ISO8601DateTime, null: true
      field :voided_at, GraphQL::Types::ISO8601DateTime, null: true

      field :signed_document_url, String, null: true

      field :customer, Types::Customers::Object, null: false
      field :organization, Types::Organizations::OrganizationType, null: false
      field :quote, Types::Quotes::Object, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      dataload_association :customer
      dataload_association :organization
      dataload_association :quote
    end
  end
end
