# frozen_string_literal: true

module Types
  module Organizations
    class UpdateOrganizationInput < BaseInputObject
      description "Update Organization input arguments"

      argument :authentication_methods, [Types::Organizations::AuthenticationMethodsEnum], required: false
      argument :default_currency, Types::CurrencyEnum, required: false
      argument :email, String, required: false
      argument :legal_name, String, required: false
      argument :legal_number, String, required: false
      argument :logo, String, required: false
      argument :slug, String, required: false
      argument :tax_identification_number, String, required: false

      argument :address_line1, String, required: false
      argument :address_line2, String, required: false
      argument :city, String, required: false
      argument :country, Types::CountryCodeEnum, required: false
      argument :net_payment_term, Integer, required: false
      argument :state, String, required: false
      argument :zipcode, String, required: false

      argument :webhook_url, String, required: false, permission: "developers:manage"

      argument :timezone, Types::TimezoneEnum, required: false

      argument :eu_tax_management, Boolean, required: false

      argument :document_number_prefix, String, required: false
      argument :document_numbering, Types::Organizations::DocumentNumberingEnum, required: false

      argument :billing_configuration, Types::Organizations::BillingConfigurationInput, required: false, permission: "organization:invoices:view"
      argument :email_settings, [Types::Organizations::EmailSettingsEnum], required: false, permission: "organization:emails:view"
      argument :finalize_zero_amount_invoice, Boolean, required: false
    end
  end
end
