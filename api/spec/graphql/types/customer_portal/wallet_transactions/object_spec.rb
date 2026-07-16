# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::CustomerPortal::WalletTransactions::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:wallet).of_type("CustomerPortalWallet")

    expect(subject).to have_field(:amount).of_type("String!")
    expect(subject).to have_field(:credit_amount).of_type("String!")
    expect(subject).to have_field(:status).of_type("WalletTransactionStatusEnum!")
    expect(subject).to have_field(:transaction_status).of_type("WalletTransactionTransactionStatusEnum!")
    expect(subject).to have_field(:transaction_type).of_type("WalletTransactionTransactionTypeEnum!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:settled_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
