# frozen_string_literal: true

module Types
  module Customers
    class UpdateCustomerInput < BaseInputObject
      description "Update Customer input arguments"

      argument :id, ID, required: true

      argument :account_type, Types::Customers::AccountTypeEnum, required: false
      argument :address_line1, String, required: false, permission: "customers:update"
      argument :address_line2, String, required: false, permission: "customers:update"
      argument :city, String, required: false, permission: "customers:update"
      argument :country, Types::CountryCodeEnum, required: false, permission: "customers:update"
      argument :currency, Types::CurrencyEnum, required: false, permission: "customers:update"
      argument :customer_type, Types::Customers::CustomerTypeEnum, required: false, permission: "customers:update"
      argument :email, String, required: false, permission: "customers:update"
      argument :external_id, String, required: true, permission: "customers:update"
      argument :external_salesforce_id, String, required: false, permission: "customers:update"
      argument :firstname, String, required: false, permission: "customers:update"
      argument :lastname, String, required: false, permission: "customers:update"
      argument :legal_name, String, required: false, permission: "customers:update"
      argument :legal_number, String, required: false, permission: "customers:update"
      argument :logo_url, String, required: false, permission: "customers:update"
      argument :name, String, required: false, permission: "customers:update"
      argument :phone, String, required: false, permission: "customers:update"
      argument :state, String, required: false, permission: "customers:update"
      argument :tax_identification_number, String, required: false, permission: "customers:update"
      argument :timezone, Types::TimezoneEnum, required: false, permission: "customers:update"
      argument :url, String, required: false, permission: "customers:update"
      argument :zipcode, String, required: false, permission: "customers:update"

      argument :billing_entity_code, String, required: false, permission: "customers:update"
      argument :shipping_address, Types::Customers::AddressInput, required: false, permission: "customers:update"

      argument :metadata, [Types::Customers::Metadata::Input], required: false, permission: "customers:update"

      argument :payment_provider, Types::PaymentProviders::ProviderTypeEnum, required: false, permission: "customers:update"
      argument :payment_provider_code, String, required: false, permission: "customers:update"
      argument :provider_customer, Types::PaymentProviderCustomers::ProviderInput, required: false, permission: "customers:update"

      argument :integration_customers, [Types::IntegrationCustomers::Input], required: false, permission: "customers:update"

      # Customer settings
      argument :invoice_grace_period, Integer, required: false, permissions: %w[customers:update]
      argument :net_payment_term, Integer, required: false, permissions: %w[customers:update]
      argument :tax_codes, [String], required: false, permissions: %w[customers:update]

      argument :billing_configuration, Types::Customers::BillingConfigurationInput, required: false
      argument :finalize_zero_amount_invoice, Types::Customers::FinalizeZeroAmountInvoiceEnum, required: false

      # Dunning campaign settings
      argument :applied_dunning_campaign_id, ID, required: false
      argument :exclude_from_dunning_campaign, Boolean, required: false

      # Invoice custom sections settings
      argument :configurable_invoice_custom_section_ids, [ID], required: false
      argument :skip_invoice_custom_sections, Boolean, required: false
    end
  end
end
