# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillingEntities::Object do
  subject { described_class }

  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:organization).of_type("Organization!") }
  it { is_expected.to have_field(:code).of_type("String!") }
  it { is_expected.to have_field(:name).of_type("String!") }
  it { is_expected.to have_field(:logo_url).of_type("String") }
  it { is_expected.to have_field(:timezone).of_type("TimezoneEnum") }
  it { is_expected.to have_field(:default_currency).of_type("CurrencyEnum!") }
  it { is_expected.to have_field(:email).of_type("String") }

  it { is_expected.to have_field(:legal_name).of_type("String") }
  it { is_expected.to have_field(:legal_number).of_type("String") }
  it { is_expected.to have_field(:tax_identification_number).of_type("String") }

  it { is_expected.to have_field(:address_line1).of_type("String") }
  it { is_expected.to have_field(:address_line2).of_type("String") }
  it { is_expected.to have_field(:city).of_type("String") }
  it { is_expected.to have_field(:country).of_type("CountryCode") }
  it { is_expected.to have_field(:net_payment_term).of_type("Int!") }
  it { is_expected.to have_field(:state).of_type("String") }
  it { is_expected.to have_field(:zipcode).of_type("String") }

  it { is_expected.to have_field(:document_number_prefix).of_type("String!") }
  it { is_expected.to have_field(:document_numbering).of_type("BillingEntityDocumentNumberingEnum!") }

  it { is_expected.to have_field(:created_at).of_type("ISO8601DateTime!") }
  it { is_expected.to have_field(:updated_at).of_type("ISO8601DateTime!") }

  it { is_expected.to have_field(:eu_tax_management).of_type("Boolean!") }
  it { is_expected.to have_field(:billing_configuration).of_type("BillingEntityBillingConfiguration") }
  it { is_expected.to have_field(:email_settings).of_type("[BillingEntityEmailSettingsEnum!]") }
  it { is_expected.to have_field(:finalize_zero_amount_invoice).of_type("Boolean!") }
  it { is_expected.to have_field(:einvoicing).of_type("Boolean!") }

  it { is_expected.to have_field(:applied_dunning_campaign).of_type("DunningCampaign") }
  it { is_expected.to have_field(:is_default).of_type("Boolean!") }

  it { is_expected.to have_field(:selected_invoice_custom_sections).of_type("[InvoiceCustomSection!]") }
end
