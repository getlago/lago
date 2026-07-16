# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Wallets::UpdateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:expiration_at).of_type("ISO8601DateTime")
    expect(subject).to accept_argument(:id).of_type("ID!")
    expect(subject).to accept_argument(:billing_entity_id).of_type("ID")
    expect(subject).to accept_argument(:code).of_type("String")
    expect(subject).to accept_argument(:invoice_requires_successful_payment).of_type("Boolean")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:priority).of_type("Int!")

    expect(subject).to accept_argument(:paid_top_up_max_amount_cents).of_type("BigInt")
    expect(subject).to accept_argument(:paid_top_up_min_amount_cents).of_type("BigInt")

    expect(subject).to accept_argument(:recurring_transaction_rules).of_type("[UpdateRecurringTransactionRuleInput!]")
    expect(subject).to accept_argument(:invoice_custom_section).of_type("InvoiceCustomSectionsReferenceInput")

    expect(subject).to accept_argument(:applies_to).of_type("AppliesToInput")

    expect(subject).to accept_argument(:metadata).of_type("[MetadataInput!]")

    expect(subject).to accept_argument(:payment_method).of_type("PaymentMethodReferenceInput")
  end
end
