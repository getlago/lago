# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactionConsumption do
  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:inbound_wallet_transaction).class_name("WalletTransaction").inverse_of(:consumptions)
      expect(subject).to belong_to(:outbound_wallet_transaction).class_name("WalletTransaction").inverse_of(:fundings)
    end
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:consumed_amount_cents).is_greater_than(0) }

    describe "inbound_transaction_must_be_inbound" do
      let(:wallet) { create(:wallet) }
      let(:inbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: :inbound, remaining_amount_cents: 10000) }
      let(:outbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: :outbound) }

      it "is valid when inbound_wallet_transaction is inbound" do
        consumption = build(:wallet_transaction_consumption,
          inbound_wallet_transaction: inbound_transaction,
          outbound_wallet_transaction: outbound_transaction)

        expect(consumption).to be_valid
      end

      it "is invalid when inbound_wallet_transaction is outbound" do
        consumption = build(:wallet_transaction_consumption,
          inbound_wallet_transaction: outbound_transaction,
          outbound_wallet_transaction: outbound_transaction)

        expect(consumption).not_to be_valid
        expect(consumption.errors.where(:inbound_wallet_transaction, :invalid)).to be_present
      end
    end

    describe "outbound_transaction_must_be_outbound" do
      let(:wallet) { create(:wallet) }
      let(:inbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: :inbound, remaining_amount_cents: 10000) }
      let(:outbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: :outbound) }

      it "is valid when outbound_wallet_transaction is outbound" do
        consumption = build(:wallet_transaction_consumption,
          inbound_wallet_transaction: inbound_transaction,
          outbound_wallet_transaction: outbound_transaction)

        expect(consumption).to be_valid
      end

      it "is invalid when outbound_wallet_transaction is inbound" do
        consumption = build(:wallet_transaction_consumption,
          inbound_wallet_transaction: inbound_transaction,
          outbound_wallet_transaction: inbound_transaction)

        expect(consumption).not_to be_valid
        expect(consumption.errors.where(:outbound_wallet_transaction, :invalid)).to be_present
      end
    end
  end

  describe "#credit_amount" do
    let(:wallet) { create(:wallet, rate_amount: "2.00", currency: "EUR") }
    let(:inbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: :inbound, remaining_amount_cents: 10000) }
    let(:outbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: :outbound) }
    let(:consumption) do
      create(:wallet_transaction_consumption,
        inbound_wallet_transaction: inbound_transaction,
        outbound_wallet_transaction: outbound_transaction,
        consumed_amount_cents: 3000)
    end

    it "converts consumed cents to credit amount using the wallet rate" do
      # 3000 cents = 30.00 EUR, at rate 2.00 => 15.0 credits
      expect(consumption.credit_amount).to eq("15.0")
    end
  end
end
