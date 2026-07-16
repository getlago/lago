# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WalletTransactions::CreateInput do
  subject { described_class }

  it "has the expected arguments" do
    expect(subject).to accept_argument(:wallet_id).of_type("ID!")

    expect(subject).to accept_argument(:granted_credits).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:ignore_paid_top_up_limits).of_type("Boolean")
    expect(subject).to accept_argument(:invoice_requires_successful_payment).of_type("Boolean")
    expect(subject).to accept_argument(:invoice_custom_section).of_type("InvoiceCustomSectionsReferenceInput")
    expect(subject).to accept_argument(:metadata).of_type("[WalletTransactionMetadataInput!]")
    expect(subject).to accept_argument(:paid_credits).of_type("String")
    expect(subject).to accept_argument(:payment_method).of_type("PaymentMethodReferenceInput")
    expect(subject).to accept_argument(:priority).of_type("Int")
    expect(subject).to accept_argument(:voided_credits).of_type("String")
  end
end
