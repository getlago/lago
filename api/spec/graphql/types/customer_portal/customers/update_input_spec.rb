# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::CustomerPortal::Customers::UpdateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:customer_type).of_type("CustomerTypeEnum")
    expect(subject).to accept_argument(:document_locale).of_type("String")
    expect(subject).to accept_argument(:email).of_type("String")
    expect(subject).to accept_argument(:firstname).of_type("String")
    expect(subject).to accept_argument(:lastname).of_type("String")
    expect(subject).to accept_argument(:legal_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:tax_identification_number).of_type("String")

    expect(subject).to accept_argument(:address_line1).of_type("String")
    expect(subject).to accept_argument(:address_line2).of_type("String")
    expect(subject).to accept_argument(:city).of_type("String")
    expect(subject).to accept_argument(:country).of_type("CountryCode")
    expect(subject).to accept_argument(:state).of_type("String")
    expect(subject).to accept_argument(:zipcode).of_type("String")

    expect(subject).to accept_argument(:shipping_address).of_type("CustomerAddressInput")
  end
end
