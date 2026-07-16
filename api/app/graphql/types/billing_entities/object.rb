# frozen_string_literal: true

module Types
  module BillingEntities
    class Object < Types::BaseObject
      graphql_name "BillingEntity"
      description "Base billing entity"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType, null: false

      field :code, String, null: false
      field :default_currency, Types::CurrencyEnum, null: false
      field :einvoicing, Boolean, null: false
      field :email, String
      field :logo_url, String
      field :name, String, null: false
      field :timezone, Types::TimezoneEnum

      field :legal_name, String
      field :legal_number, String
      field :tax_identification_number, String

      field :address_line1, String
      field :address_line2, String
      field :city, String
      field :country, Types::CountryCodeEnum
      field :net_payment_term, Integer, null: false
      field :phone, String
      field :state, String
      field :zipcode, String

      field :document_number_prefix, String, null: false
      field :document_numbering, Types::BillingEntities::DocumentNumberingEnum, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :eu_tax_management, Boolean, null: false

      field :billing_configuration, Types::BillingEntities::BillingConfiguration, permission: "billing_entities:view"
      field :email_settings, [Types::BillingEntities::EmailSettingsEnum], permission: "billing_entities:view"
      field :finalize_zero_amount_invoice, Boolean, null: false
      field :is_default, Boolean, null: false

      field :applied_dunning_campaign, Types::DunningCampaigns::Object

      field :selected_invoice_custom_sections, [Types::InvoiceCustomSections::Object]

      def is_default
        object.organization.default_billing_entity&.id == object.id
      end

      def billing_configuration
        {
          id: "#{object&.id}-c1nf", # Each nested object needs ID so that appollo cache system can work properly
          document_locale: object&.document_locale,
          invoice_footer: object&.invoice_footer,
          invoice_grace_period: object&.invoice_grace_period,
          subscription_invoice_issuing_date_anchor: object&.subscription_invoice_issuing_date_anchor,
          subscription_invoice_issuing_date_adjustment: object&.subscription_invoice_issuing_date_adjustment
        }
      end
    end
  end
end
