# frozen_string_literal: true

module Types
  module CreditNotes
    class Estimate < Types::BaseObject
      description "Estimate amounts for credit note creation"
      graphql_name "CreditNoteEstimate"

      field :currency, Types::CurrencyEnum, null: false

      field :coupons_adjustment_amount_cents, GraphQL::Types::BigInt, null: false
      field :max_creditable_amount_cents, GraphQL::Types::BigInt, method: :credit_amount_cents, null: false
      field :max_offsettable_amount_cents, GraphQL::Types::BigInt, null: false
      field :max_refundable_amount_cents, GraphQL::Types::BigInt, method: :refund_amount_cents, null: false
      field :precise_coupons_adjustment_amount_cents, GraphQL::Types::Float, null: false
      field :sub_total_excluding_taxes_amount_cents, GraphQL::Types::BigInt, null: false

      field :precise_taxes_amount_cents, GraphQL::Types::Float, null: false
      field :taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :taxes_rate, GraphQL::Types::Float, null: false

      field :items, [Types::CreditNoteItems::Estimate], null: false

      field :applied_taxes, [Types::CreditNotes::AppliedTaxes::Object], null: false

      def max_offsettable_amount_cents
        creditable = object.credit_amount_cents.to_i
        due = object.invoice&.total_due_amount_cents.to_i

        due.clamp(0, creditable)
      end
    end
  end
end
