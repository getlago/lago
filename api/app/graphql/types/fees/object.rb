# frozen_string_literal: true

module Types
  module Fees
    class Object < Types::BaseObject
      graphql_name "Fee"
      implements Types::Invoices::InvoiceItem

      field :id, ID, null: false

      field :add_on, Types::AddOns::Object, null: true
      field :charge, Types::Charges::Object, null: true
      field :currency, Types::CurrencyEnum, null: false
      field :description, String, null: true
      field :fixed_charge, Types::FixedCharges::Object, null: true
      field :grouped_by, GraphQL::Types::JSON, null: false
      field :invoice_display_name, String, null: true
      field :invoice_id, ID, null: true
      field :invoice_name, String, null: true
      field :subscription, Types::Subscriptions::Object, null: true
      field :true_up_fee, Types::Fees::Object, null: true
      field :true_up_parent_fee, Types::Fees::Object, null: true
      field :wallet_transaction, Types::WalletTransactions::Object, null: true

      field :creditable_amount_cents, GraphQL::Types::BigInt, null: false
      field :events_count, GraphQL::Types::BigInt, null: true
      field :fee_type, Types::Fees::TypesEnum, null: false
      field :offsettable_amount_cents, GraphQL::Types::BigInt, null: false
      field :pay_in_advance, Boolean, null: false
      field :precise_amount_cents, GraphQL::Types::Float, null: false
      field :precise_coupons_amount_cents, GraphQL::Types::Float, null: false
      field :precise_total_amount_cents, GraphQL::Types::Float, null: false
      field :precise_unit_amount, GraphQL::Types::Float, null: false
      field :sub_total_excluding_taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :sub_total_excluding_taxes_precise_amount_cents, GraphQL::Types::Float, null: false
      field :succeeded_at, GraphQL::Types::ISO8601DateTime, null: true
      field :taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :taxes_precise_amount_cents, GraphQL::Types::Float, null: false
      field :taxes_rate, GraphQL::Types::Float, null: true
      field :total_amount_cents, GraphQL::Types::BigInt, null: false
      field :units, GraphQL::Types::Float, null: false

      field :applied_taxes, [Types::Fees::AppliedTaxes::Object]

      field :amount_details, Types::Fees::AmountDetails::Object, null: true

      field :adjusted_fee, Boolean, null: false
      field :adjusted_fee_type, Types::AdjustedFees::AdjustedFeeTypeEnum, null: true

      field :charge_filter, Types::ChargeFilters::Object, null: true
      field :presentation_breakdowns, [Types::Customers::Usage::PresentationBreakdown], null: true
      field :pricing_unit_usage, Types::PricingUnitUsages::Object, null: true
      field :properties, Types::Fees::Properties, null: true, method: :itself

      def wallet_transaction
        object.invoiceable if object.credit?
      end

      def item_type
        object.fee_type
      end

      def applied_taxes
        if object.applied_taxes.any? { |t| !t.persisted? }
          object.applied_taxes.sort_by { |tax| -tax.tax_rate.to_f }
        else
          object.applied_taxes.order(tax_rate: :desc)
        end
      end

      def adjusted_fee
        object.adjusted_fee.present?
      end

      def adjusted_fee_type
        return nil if object.adjusted_fee.blank?
        return nil if object.adjusted_fee.adjusted_display_name?

        object.adjusted_fee.adjusted_units? ? "adjusted_units" : "adjusted_amount"
      end

      def presentation_breakdowns
        Types::Fees::PresentationBreakdownBuilder.call(
          [object],
          filter: Types::Fees::PresentationBreakdownBuilder::ALL,
          filter_breakdown: Types::Fees::PresentationBreakdownBuilder::DISPLAY_IN_INVOICE
        )
      end
    end
  end
end
