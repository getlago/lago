# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Organizations::UpdateOrganizationInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:authentication_methods).of_type("[AuthenticationMethodsEnum!]")
    expect(subject).to accept_argument(:default_currency).of_type("CurrencyEnum")
    expect(subject).to accept_argument(:email).of_type("String")
    expect(subject).to accept_argument(:slug).of_type("String")
    expect(subject).to accept_argument(:legal_name).of_type("String")
    expect(subject).to accept_argument(:legal_number).of_type("String")
    expect(subject).to accept_argument(:logo).of_type("String")
    expect(subject).to accept_argument(:tax_identification_number).of_type("String")

    expect(subject).to accept_argument(:address_line1).of_type("String")
    expect(subject).to accept_argument(:address_line2).of_type("String")
    expect(subject).to accept_argument(:city).of_type("String")
    expect(subject).to accept_argument(:country).of_type("CountryCode")
    expect(subject).to accept_argument(:net_payment_term).of_type("Int")
    expect(subject).to accept_argument(:state).of_type("String")
    expect(subject).to accept_argument(:zipcode).of_type("String")

    expect(subject).to accept_argument(:document_numbering).of_type("DocumentNumberingEnum")
    expect(subject).to accept_argument(:document_number_prefix).of_type("String")

    expect(subject).to accept_argument(:webhook_url).of_type("String").with_permission("developers:manage")

    expect(subject).to accept_argument(:timezone).of_type("TimezoneEnum")

    expect(subject).to accept_argument(:billing_configuration).of_type("OrganizationBillingConfigurationInput").with_permission("organization:invoices:view")
    expect(subject).to accept_argument(:email_settings).of_type("[EmailSettingsEnum!]").with_permission("organization:emails:view")
    expect(subject).to accept_argument(:finalize_zero_amount_invoice).of_type("Boolean")
  end
end
