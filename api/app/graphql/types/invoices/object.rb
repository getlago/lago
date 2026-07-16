# frozen_string_literal: true

module Types
  module Invoices
    class Object < Types::BaseObject
      description "Invoice"
      graphql_name "Invoice"

      field :billing_entity, Types::BillingEntities::Object, null: false
      field :customer, Types::Customers::Object, null: false

      field :id, ID, null: false
      field :number, String, null: false
      field :sequential_id, ID, null: false

      field :self_billed, Boolean, null: false
      field :version_number, Integer, null: false

      field :invoice_type, Types::Invoices::InvoiceTypeEnum, null: false
      field :payment_dispute_losable, Boolean, null: false, method: :payment_dispute_losable?
      field :payment_dispute_lost_at, GraphQL::Types::ISO8601DateTime
      field :payment_status, Types::Invoices::PaymentStatusTypeEnum, null: false
      field :purchase_order_number, String, null: true
      field :status, Types::Invoices::StatusTypeEnum, null: false
      field :tax_status, Types::Invoices::TaxStatusTypeEnum, null: true
      field :voidable, Boolean, null: false, method: :voidable?

      field :currency, Types::CurrencyEnum
      field :taxes_rate, Float, null: false

      field :charge_amount_cents, GraphQL::Types::BigInt, null: false
      field :coupons_amount_cents, GraphQL::Types::BigInt, null: false
      field :credit_notes_amount_cents, GraphQL::Types::BigInt, null: false
      field :fees_amount_cents, GraphQL::Types::BigInt, null: false
      field :prepaid_credit_amount_cents, GraphQL::Types::BigInt, null: false
      field :prepaid_granted_credit_amount_cents, GraphQL::Types::BigInt, null: true
      field :prepaid_purchased_credit_amount_cents, GraphQL::Types::BigInt, null: true
      field :progressive_billing_credit_amount_cents, GraphQL::Types::BigInt, null: false
      field :ready_for_payment_processing, Boolean, null: false
      field :sub_total_excluding_taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :sub_total_including_taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :total_amount_cents, GraphQL::Types::BigInt, null: false
      field :total_due_amount_cents, GraphQL::Types::BigInt, null: false
      field :total_paid_amount_cents, GraphQL::Types::BigInt, null: false
      field :total_settled_amount_cents, GraphQL::Types::BigInt, null: false

      field :expected_finalization_date, GraphQL::Types::ISO8601Date, null: false
      field :issuing_date, GraphQL::Types::ISO8601Date, null: false
      field :payment_due_date, GraphQL::Types::ISO8601Date, null: false
      field :payment_overdue, Boolean, null: false

      field :all_charges_have_fees, Boolean, null: false, method: :all_charges_have_fees?
      field :all_fixed_charges_have_fees, Boolean, null: false, method: :all_fixed_charges_have_fees?

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :associated_active_wallet_present, Boolean, null: false
      field :available_to_credit_amount_cents, GraphQL::Types::BigInt, null: false
      field :creditable_amount_cents, GraphQL::Types::BigInt, null: false
      field :offsettable_amount_cents, GraphQL::Types::BigInt, null: false
      field :refundable_amount_cents, GraphQL::Types::BigInt, null: false

      field :file_url, String, null: true
      field :xml_url, String, null: true

      field :metadata, [Types::Invoices::Metadata::Object], null: true

      field :activity_logs, [Types::ActivityLogs::Object], null: true
      field :applied_taxes, [Types::Invoices::AppliedTaxes::Object]
      field :credit_notes, [Types::CreditNotes::Object], null: true
      field :error_details, [Types::ErrorDetails::Object], null: true
      field :fees, [Types::Fees::Object], null: true
      field :invoice_subscriptions, [Types::InvoiceSubscriptions::Object], method: :sorted_invoice_subscriptions
      field :subscriptions, [Types::Subscriptions::Object], method: :sorted_subscriptions

      field :external_hubspot_integration_id, String, null: true
      field :external_integration_id, String, null: true
      field :external_salesforce_integration_id, String, null: true
      field :integration_hubspot_syncable, GraphQL::Types::Boolean, null: false
      field :integration_salesforce_syncable, GraphQL::Types::Boolean, null: false
      field :integration_syncable, GraphQL::Types::Boolean, null: false
      field :payable_type, GraphQL::Types::String, null: false
      field :payments, [Types::Payments::Object], null: true, method: :customer_payments
      field :regenerated_invoice_id, String, null: true
      field :tax_provider_id, String, null: true
      field :tax_provider_voidable, GraphQL::Types::Boolean, null: false
      field :voided_at, GraphQL::Types::ISO8601DateTime, null: true
      field :voided_invoice_id, String, null: true

      def payable_type
        "Invoice"
      end

      def regenerated_invoice_id
        object.regenerated_invoice&.id
      end

      def applied_taxes
        if object.applied_taxes.any? { |applied_tax| !applied_tax.persisted? }
          object.applied_taxes.sort_by { |applied_tax| -applied_tax.tax_rate.to_f }
        else
          object.applied_taxes.order(tax_rate: :desc)
        end
      end

      def integration_syncable
        object.should_sync_invoice? &&
          object.integration_resources
            .joins(:integration)
            .where(integration: {type: ::Integrations::BaseIntegration::INTEGRATION_ACCOUNTING_TYPES})
            .where(resource_type: "invoice", syncable_type: "Invoice").none?
      end

      def integration_hubspot_syncable
        object.should_sync_hubspot_invoice? &&
          object.integration_resources
            .joins(:integration)
            .where(integration: {type: "Integrations::HubspotIntegration"})
            .where(resource_type: "invoice", syncable_type: "Invoice").none?
      end

      def integration_salesforce_syncable
        object.should_sync_salesforce_invoice? &&
          object.integration_resources
            .joins(:integration)
            .where(integration: {type: "Integrations::SalesforceIntegration"})
            .where(resource_type: "invoice", syncable_type: "Invoice").none?
      end

      def tax_provider_voidable
        return false if !object.voided? && !object.payment_dispute_lost_at

        object.error_details.tax_voiding_error.any?
      end

      def external_salesforce_integration_id
        integration_customer = object.customer&.integration_customers&.salesforce_kind&.first

        return nil unless integration_customer

        IntegrationResource.find_by(
          integration: integration_customer.integration,
          syncable_id: object.id,
          syncable_type: "Invoice",
          resource_type: :invoice
        )&.external_id
      end

      def external_hubspot_integration_id
        integration_customer = object.customer&.integration_customers&.hubspot_kind&.first

        return nil unless integration_customer

        IntegrationResource.find_by(
          integration: integration_customer.integration,
          syncable_id: object.id,
          syncable_type: "Invoice",
          resource_type: :invoice
        )&.external_id
      end

      def external_integration_id
        integration_customer = object.customer&.integration_customers&.accounting_kind&.first

        return nil unless integration_customer

        IntegrationResource.find_by(
          integration: integration_customer.integration,
          syncable_id: object.id,
          syncable_type: "Invoice",
          resource_type: :invoice
        )&.external_id
      end

      def associated_active_wallet_present
        object.associated_active_wallet.present?
      end

      def tax_provider_id
        integration_customer = object.customer&.tax_customer
        return nil unless integration_customer

        IntegrationResource.find_by(
          integration: integration_customer.integration,
          syncable_id: object.id,
          syncable_type: "Invoice",
          resource_type: :invoice
        )&.external_id
      end
    end
  end
end
