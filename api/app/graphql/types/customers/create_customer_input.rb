# frozen_string_literal: true

module Types
  module Customers
    class CreateCustomerInput < BaseInputObject
      description "Create Customer input arguments"

      argument :account_type, Types::Customers::AccountTypeEnum, required: false
      argument :address_line1, String, required: false
      argument :address_line2, String, required: false
      argument :city, String, required: false
      argument :country, Types::CountryCodeEnum, required: false
      argument :currency, Types::CurrencyEnum, required: false
      argument :customer_type, Types::Customers::CustomerTypeEnum, required: false
      argument :email, String, required: false
      argument :external_id, String, required: true
      argument :external_salesforce_id, String, required: false
      argument :firstname, String, required: false
      argument :invoice_grace_period, Integer, required: false
      argument :lastname, String, required: false
      argument :legal_name, String, required: false
      argument :legal_number, String, required: false
      argument :logo_url, String, required: false
      argument :name, String, required: false
      argument :net_payment_term, Integer, required: false
      argument :phone, String, required: false
      argument :state, String, required: false
      argument :tax_codes, [String], required: false
      argument :tax_identification_number, String, required: false
      argument :timezone, Types::TimezoneEnum, required: false
      argument :url, String, required: false
      argument :zipcode, String, required: false

      argument :billing_entity_code, String, required: false
      argument :shipping_address, Types::Customers::AddressInput, required: false

      argument :metadata, [Types::Customers::Metadata::Input], required: false

      argument :payment_provider, Types::PaymentProviders::ProviderTypeEnum, required: false
      argument :payment_provider_code, String, required: false
      argument :provider_customer, Types::PaymentProviderCustomers::ProviderInput, required: false

      argument :integration_customers, [Types::IntegrationCustomers::Input], required: false

      argument :billing_configuration, Types::Customers::BillingConfigurationInput, required: false
      argument :finalize_zero_amount_invoice, Types::Customers::FinalizeZeroAmountInvoiceEnum, required: false
    end
  end
end
