# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::UpdateCustomerInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID!")

    expect(subject).to accept_argument(:account_type).of_type(Types::Customers::AccountTypeEnum)
    expect(subject).to accept_argument(:address_line1).of_type("String")
    expect(subject).to accept_argument(:address_line2).of_type("String")
    expect(subject).to accept_argument(:city).of_type("String")
    expect(subject).to accept_argument(:country).of_type("CountryCode")
    expect(subject).to accept_argument(:currency).of_type("CurrencyEnum")
    expect(subject).to accept_argument(:customer_type).of_type("CustomerTypeEnum")
    expect(subject).to accept_argument(:email).of_type("String")
    expect(subject).to accept_argument(:external_id).of_type("String!")
    expect(subject).to accept_argument(:external_salesforce_id).of_type("String")
    expect(subject).to accept_argument(:firstname).of_type("String")
    expect(subject).to accept_argument(:invoice_grace_period).of_type("Int")
    expect(subject).to accept_argument(:lastname).of_type("String")
    expect(subject).to accept_argument(:legal_name).of_type("String")
    expect(subject).to accept_argument(:legal_number).of_type("String")
    expect(subject).to accept_argument(:logo_url).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:net_payment_term).of_type("Int")
    expect(subject).to accept_argument(:phone).of_type("String")
    expect(subject).to accept_argument(:state).of_type("String")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
    expect(subject).to accept_argument(:tax_identification_number).of_type("String")
    expect(subject).to accept_argument(:timezone).of_type("TimezoneEnum")
    expect(subject).to accept_argument(:url).of_type("String")
    expect(subject).to accept_argument(:zipcode).of_type("String")
    expect(subject).to accept_argument(:shipping_address).of_type("CustomerAddressInput")
    expect(subject).to accept_argument(:metadata).of_type("[CustomerMetadataInput!]")
    expect(subject).to accept_argument(:payment_provider).of_type("ProviderTypeEnum")
    expect(subject).to accept_argument(:payment_provider_code).of_type("String")
    expect(subject).to accept_argument(:provider_customer).of_type("ProviderCustomerInput")
    expect(subject).to accept_argument(:integration_customers).of_type("[IntegrationCustomerInput!]")
    expect(subject).to accept_argument(:billing_configuration).of_type("CustomerBillingConfigurationInput")

    expect(subject).to accept_argument(:applied_dunning_campaign_id).of_type("ID")
    expect(subject).to accept_argument(:exclude_from_dunning_campaign).of_type("Boolean")
    expect(subject).to accept_argument(:billing_entity_code).of_type("String")

    expect(subject).to accept_argument(:configurable_invoice_custom_section_ids).of_type("[ID!]")
    expect(subject).to accept_argument(:skip_invoice_custom_sections).of_type("Boolean")
  end
end
