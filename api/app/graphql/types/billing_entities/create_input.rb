# frozen_string_literal: true

module Types
  module BillingEntities
    class CreateInput < BaseInputObject
      description "Create Billing Entity input arguments"

      argument :code, String, required: true
      argument :name, String, required: true

      argument :default_currency, Types::CurrencyEnum, required: false
      argument :einvoicing, Boolean, required: false
      argument :email, String, required: false
      argument :legal_name, String, required: false
      argument :legal_number, String, required: false
      argument :logo, String, required: false
      argument :tax_identification_number, String, required: false

      argument :address_line1, String, required: false
      argument :address_line2, String, required: false
      argument :city, String, required: false
      argument :country, Types::CountryCodeEnum, required: false
      argument :net_payment_term, Integer, required: false
      argument :phone, String, required: false
      argument :state, String, required: false
      argument :zipcode, String, required: false

      argument :timezone, Types::TimezoneEnum, required: false

      argument :eu_tax_management, Boolean, required: false

      argument :document_number_prefix, String, required: false
      argument :document_numbering, Types::BillingEntities::DocumentNumberingEnum, required: false

      argument :billing_configuration, Types::BillingEntities::BillingConfigurationInput, required: false, permission: "billing_entities:view"
      argument :email_settings, [Types::BillingEntities::EmailSettingsEnum], required: false, permission: "billing_entities:view"
      argument :finalize_zero_amount_invoice, Boolean, required: false
    end
  end
end
