# frozen_string_literal: true

module Types
  module PaymentMethods
    class Object < Types::BaseObject
      graphql_name "PaymentMethod"

      field :id, ID, null: false

      field :customer, Types::Customers::Object, null: false
      field :details, Types::PaymentMethods::Details, null: true
      field :is_default, Boolean, null: false
      field :payment_provider_code, String, null: true
      field :payment_provider_customer_id, ID, null: true
      field :payment_provider_name, String, null: true
      field :payment_provider_type, Types::PaymentProviders::ProviderTypeEnum, null: true
      field :provider_method_id, String, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: true

      def payment_provider_code
        object.payment_provider&.code
      end

      def payment_provider_name
        object.payment_provider&.name
      end
    end
  end
end
