# frozen_string_literal: true

module Types
  module PaymentReceipts
    class Object < Types::BaseObject
      description "PaymentReceipt"
      graphql_name "PaymentReceipt"

      field :id, ID, null: false

      field :file_url, String, null: true
      field :number, String, null: false
      field :organization, Types::Organizations::OrganizationType, null: false
      field :payment, Types::Payments::Object, null: false
      field :xml_url, String, null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
