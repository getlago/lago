# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::CreateInvoiceInput do
  subject { described_class }

  it "has the expected arguments with correct types" do
    expect(subject).to accept_argument(:billing_entity_id).of_type("ID")
    expect(subject).to accept_argument(:currency).of_type("CurrencyEnum")
    expect(subject).to accept_argument(:customer_id).of_type("ID!")
    expect(subject).to accept_argument(:fees).of_type("[FeeInput!]!")
    expect(subject).to accept_argument(:invoice_custom_section).of_type("InvoiceCustomSectionsReferenceInput")
    expect(subject).to accept_argument(:payment_method).of_type("PaymentMethodReferenceInput")
    expect(subject).to accept_argument(:voided_invoice_id).of_type("ID")
  end
end
