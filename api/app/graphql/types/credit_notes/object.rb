# frozen_string_literal: true

module Types
  module CreditNotes
    class Object < Types::BaseObject
      description "CreditNote"
      graphql_name "CreditNote"

      field :id, ID, null: false
      field :number, String, null: false
      field :sequential_id, ID, null: false

      field :issuing_date, GraphQL::Types::ISO8601Date, null: false

      field :description, String, null: true
      field :reason, Types::CreditNotes::ReasonTypeEnum, null: false

      field :credit_status, Types::CreditNotes::CreditStatusTypeEnum, null: true
      field :refund_status, Types::CreditNotes::RefundStatusTypeEnum, null: true

      field :currency, Types::CurrencyEnum, null: false
      field :taxes_rate, Float, null: false

      field :balance_amount_cents, GraphQL::Types::BigInt, null: false
      field :coupons_adjustment_amount_cents, GraphQL::Types::BigInt, null: false
      field :credit_amount_cents, GraphQL::Types::BigInt, null: false
      field :offset_amount_cents, GraphQL::Types::BigInt, null: false
      field :refund_amount_cents, GraphQL::Types::BigInt, null: false
      field :sub_total_excluding_taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :taxes_amount_cents, GraphQL::Types::BigInt, null: false
      field :total_amount_cents, GraphQL::Types::BigInt, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :refunded_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      field :voided_at, GraphQL::Types::ISO8601DateTime, null: true

      field :file_url, String, null: true
      field :xml_url, String, null: true

      field :activity_logs, [Types::ActivityLogs::Object], null: true
      field :applied_taxes, [Types::CreditNotes::AppliedTaxes::Object]
      field :billing_entity, Types::BillingEntities::Object, null: false
      field :customer, Types::Customers::Object, null: false
      field :invoice, Types::Invoices::Object
      field :items, [Types::CreditNoteItems::Object], null: false

      field :can_be_voided, Boolean, null: false, method: :voidable? do
        description "Check if credit note can be voided"
      end

      field :error_details, [Types::ErrorDetails::Object], null: true
      field :external_integration_id, String, null: true
      field :integration_syncable, GraphQL::Types::Boolean, null: false
      field :metadata, [Types::Metadata::Object], null: true
      field :tax_provider_id, String, null: true
      field :tax_provider_syncable, GraphQL::Types::Boolean, null: false

      def metadata
        object.metadata&.value
      end

      def applied_taxes
        object.applied_taxes.order(tax_rate: :desc)
      end

      def integration_syncable
        object.should_sync_credit_note? &&
          object.integration_resources
            .joins(:integration)
            .where(integration: {type: ::Integrations::BaseIntegration::INTEGRATION_ACCOUNTING_TYPES})
            .where(resource_type: "credit_note", syncable_type: "CreditNote").none?
      end

      def tax_provider_syncable
        return false unless object.finalized?
        return false if object.invoice.credit?

        object.error_details.tax_error.any?
      end

      def external_integration_id
        integration_customer = object.customer&.integration_customers&.accounting_kind&.first

        return nil unless integration_customer

        IntegrationResource.find_by(
          integration: integration_customer.integration,
          syncable_id: object.id,
          syncable_type: "CreditNote",
          resource_type: :credit_note
        )&.external_id
      end

      def tax_provider_id
        integration_customer = object.customer&.tax_customer
        return nil unless integration_customer

        object.integration_resources.where(integration_id: integration_customer.integration_id).last&.external_id
      end
    end
  end
end
