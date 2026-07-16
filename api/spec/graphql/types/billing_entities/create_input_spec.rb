# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillingEntities::CreateInput do
  subject { described_class }

  it { is_expected.to accept_argument(:name).of_type("String!") }
  it { is_expected.to accept_argument(:code).of_type("String!") }
  it { is_expected.to accept_argument(:default_currency).of_type("CurrencyEnum") }
  it { is_expected.to accept_argument(:email).of_type("String") }
  it { is_expected.to accept_argument(:legal_name).of_type("String") }
  it { is_expected.to accept_argument(:legal_number).of_type("String") }
  it { is_expected.to accept_argument(:logo).of_type("String") }
  it { is_expected.to accept_argument(:tax_identification_number).of_type("String") }
  it { is_expected.to accept_argument(:address_line1).of_type("String") }
  it { is_expected.to accept_argument(:address_line2).of_type("String") }
  it { is_expected.to accept_argument(:state).of_type("String") }
  it { is_expected.to accept_argument(:country).of_type("CountryCode") }
  it { is_expected.to accept_argument(:city).of_type("String") }
  it { is_expected.to accept_argument(:zipcode).of_type("String") }
  it { is_expected.to accept_argument(:net_payment_term).of_type("Int") }
  it { is_expected.to accept_argument(:timezone).of_type("TimezoneEnum") }
  it { is_expected.to accept_argument(:eu_tax_management).of_type("Boolean") }
  it { is_expected.to accept_argument(:document_number_prefix).of_type("String") }
  it { is_expected.to accept_argument(:document_numbering).of_type("BillingEntityDocumentNumberingEnum") }
  it { is_expected.to accept_argument(:billing_configuration).of_type("BillingEntityBillingConfigurationInput") }
  it { is_expected.to accept_argument(:email_settings).of_type("[BillingEntityEmailSettingsEnum!]") }
  it { is_expected.to accept_argument(:finalize_zero_amount_invoice).of_type("Boolean") }
  it { is_expected.to accept_argument(:einvoicing).of_type("Boolean") }
end
