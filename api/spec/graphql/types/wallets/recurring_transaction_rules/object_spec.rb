# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Wallets::RecurringTransactionRules::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:lago_id).of_type("ID!")
    expect(subject).to have_field(:method).of_type("RecurringTransactionMethodEnum!")
    expect(subject).to have_field(:trigger).of_type("RecurringTransactionTriggerEnum!")
    expect(subject).to have_field(:interval).of_type("RecurringTransactionIntervalEnum")
    expect(subject).to have_field(:expiration_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:started_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:target_ongoing_balance).of_type("String")
    expect(subject).to have_field(:threshold_credits).of_type("String")
    expect(subject).to have_field(:paid_credits).of_type("String!")
    expect(subject).to have_field(:granted_credits).of_type("String!")
    expect(subject).to have_field(:grants_target_top_up).of_type("Boolean")
    expect(subject).to have_field(:ignore_paid_top_up_limits).of_type("Boolean!")
    expect(subject).to have_field(:invoice_requires_successful_payment).of_type("Boolean!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:transaction_metadata).of_type("[TransactionMetadata!]")
    expect(subject).to have_field(:selected_invoice_custom_sections).of_type("[InvoiceCustomSection!]")
    expect(subject).to have_field(:skip_invoice_custom_sections).of_type("Boolean")
    expect(subject).to have_field(:payment_method).of_type("PaymentMethod")
    expect(subject).to have_field(:payment_method_type).of_type("PaymentMethodTypeEnum")
  end
end
