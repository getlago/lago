# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::CustomerPortal::Wallets::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:code).of_type("String")
    expect(subject).to have_field(:currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:expiration_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:priority).of_type("Int!")
    expect(subject).to have_field(:status).of_type("WalletStatusEnum!")

    expect(subject).to have_field(:balance_cents).of_type("BigInt!")
    expect(subject).to have_field(:consumed_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:consumed_credits).of_type("Float!")
    expect(subject).to have_field(:credits_balance).of_type("Float!")
    expect(subject).to have_field(:credits_ongoing_balance).of_type("Float!")
    expect(subject).to have_field(:ongoing_balance_cents).of_type("BigInt!")
    expect(subject).to have_field(:ongoing_usage_balance_cents).of_type("BigInt!")
    expect(subject).to have_field(:rate_amount).of_type("Float!")
    expect(subject).to have_field(:last_balance_sync_at).of_type("ISO8601DateTime")

    expect(subject).to have_field(:paid_top_up_max_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:paid_top_up_min_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:paid_top_up_max_credits).of_type("BigInt")
    expect(subject).to have_field(:paid_top_up_min_credits).of_type("BigInt")
  end
end
