# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentRequests::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:customer).of_type("Customer!")
    expect(subject).to have_field(:invoices).of_type("[Invoice!]!")

    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:email).of_type("String!")
    expect(subject).to have_field(:payment_status).of_type("InvoicePaymentStatusTypeEnum!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
