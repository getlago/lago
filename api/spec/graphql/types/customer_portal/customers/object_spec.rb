# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::CustomerPortal::Customers::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:account_type).of_type("CustomerAccountTypeEnum!")
    expect(subject).to have_field(:applicable_timezone).of_type("TimezoneEnum!")
    expect(subject).to have_field(:currency).of_type("CurrencyEnum")
    expect(subject).to have_field(:customer_type).of_type("CustomerTypeEnum")
    expect(subject).to have_field(:display_name).of_type("String!")
    expect(subject).to have_field(:firstname).of_type("String")
    expect(subject).to have_field(:lastname).of_type("String")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:email).of_type("String")
    expect(subject).to have_field(:legal_name).of_type("String")
    expect(subject).to have_field(:legal_number).of_type("String")
    expect(subject).to have_field(:tax_identification_number).of_type("String")

    expect(subject).to have_field(:address_line1).of_type("String")
    expect(subject).to have_field(:address_line2).of_type("String")
    expect(subject).to have_field(:city).of_type("String")
    expect(subject).to have_field(:country).of_type("CountryCode")
    expect(subject).to have_field(:state).of_type("String")
    expect(subject).to have_field(:zipcode).of_type("String")

    expect(subject).to have_field(:shipping_address).of_type("CustomerAddress")

    expect(subject).to have_field(:billing_configuration).of_type("CustomerBillingConfiguration")

    expect(subject).to have_field(:premium).of_type("Boolean!")
  end
end
