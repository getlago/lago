# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Wallets::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:billing_entity_id).of_type("ID")
    expect(subject).to have_field(:customer).of_type("Customer")

    expect(subject).to have_field(:code).of_type("String")
    expect(subject).to have_field(:currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:priority).of_type("Int!")
    expect(subject).to have_field(:status).of_type("WalletStatusEnum!")

    expect(subject).to have_field(:rate_amount).of_type("Float!")

    expect(subject).to have_field(:balance_cents).of_type("BigInt!")
    expect(subject).to have_field(:consumed_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:ongoing_balance_cents).of_type("BigInt!")
    expect(subject).to have_field(:ongoing_usage_balance_cents).of_type("BigInt!")

    expect(subject).to have_field(:consumed_credits).of_type("Float!")
    expect(subject).to have_field(:credits_balance).of_type("Float!")
    expect(subject).to have_field(:credits_ongoing_balance).of_type("Float!")
    expect(subject).to have_field(:credits_ongoing_usage_balance).of_type("Float!")

    expect(subject).to have_field(:last_balance_sync_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:last_consumed_credit_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:last_ongoing_balance_sync_at).of_type("ISO8601DateTime")

    expect(subject).to have_field(:activity_logs).of_type("[ActivityLog!]")
    expect(subject).to have_field(:recurring_transaction_rules).of_type("[RecurringTransactionRule!]")

    expect(subject).to have_field(:invoice_requires_successful_payment).of_type("Boolean!")

    expect(subject).to have_field(:paid_top_up_max_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:paid_top_up_min_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:paid_top_up_max_credits).of_type("BigInt")
    expect(subject).to have_field(:paid_top_up_min_credits).of_type("BigInt")

    expect(subject).to have_field(:selected_invoice_custom_sections).of_type("[InvoiceCustomSection!]")
    expect(subject).to have_field(:skip_invoice_custom_sections).of_type("Boolean")

    expect(subject).to have_field(:payment_method).of_type("PaymentMethod")
    expect(subject).to have_field(:payment_method_type).of_type("PaymentMethodTypeEnum")

    expect(subject).to have_field(:applies_to).of_type("WalletAppliesTo")

    expect(subject).to have_field(:metadata).of_type("[ItemMetadata!]")

    expect(subject).to have_field(:traceable).of_type("Boolean!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:expiration_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:terminated_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
