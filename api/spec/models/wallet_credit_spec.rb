# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletCredit do
  subject { described_class.new(wallet:, credit_amount:, invoiceable:) }

  let(:wallet) { create(:wallet, rate_amount:, currency:) }
  let(:currency) { "EUR" }
  let(:credit_amount) { 1000 }
  let(:rate_amount) { 1 }
  let(:invoiceable) { true }

  context "with a simple wallet" do
    describe "#credit_amount" do
      it "returns the credit_amount" do
        expect(subject.credit_amount).to eq(credit_amount)
      end
    end

    describe "#amount" do
      it "returns the amount" do
        expect(subject.amount).to eq(1000)
      end
    end
  end

  context "with a low wallet rate_amount" do
    let(:rate_amount) { 0.001 }
    let(:credit_amount) { 1034 }

    describe "#credit_amount" do
      it "returns the credit_amount" do
        # The 1034 is rounded down as we cannot represent it in this currency
        expect(subject.credit_amount).to eq(1030)
      end
    end

    describe "#amount" do
      it "returns the amount" do
        expect(subject.amount).to eq(1.03)
      end
    end

    describe "#amount_cents" do
      it "returns the amount cents" do
        expect(subject.amount_cents).to eq(103)
      end
    end
  end

  describe ".from_amount_cents" do
    subject { described_class.from_amount_cents(wallet:, amount_cents:) }

    let(:amount_cents) { 10 }

    describe "#credit_amount" do
      it "returns the credit_amount" do
        expect(subject.credit_amount).to eq(0.1)
      end
    end

    describe "#amount" do
      it "returns the amount" do
        expect(subject.amount).to eq(0.1)
      end
    end

    describe "#amount_cents" do
      it "returns the amount cents" do
        expect(subject.amount_cents).to eq(10)
      end
    end

    context "when amount cents has precision" do
      let(:rate_amount) { 0.001 }
      let(:amount_cents) { BigDecimal("103.4589") }

      describe "#credit_amount" do
        it "returns the rounded credit_amount" do
          expect(subject.credit_amount).to eq(1030)
        end
      end

      describe "#amount" do
        it "returns the amount" do
          expect(subject.amount).to eq(1.03)
        end
      end

      describe "#amount_cents" do
        it "returns the amount cents" do
          expect(subject.amount_cents).to eq(103)
        end
      end
    end
  end

  describe ".rounds_to_zero?" do
    subject { described_class.rounds_to_zero?(wallet:, credit_amount:) }

    let(:rate_amount) { 0.01 }

    context "when the credit amount produces a zero monetary value" do
      let(:credit_amount) { "0.4" }

      it { is_expected.to be(true) }
    end

    context "when the credit amount produces a non-zero monetary value" do
      let(:credit_amount) { "1.0" }

      it { is_expected.to be(false) }
    end

    context "when the credit amount is strictly zero" do
      let(:credit_amount) { "0.0" }

      it { is_expected.to be(false) }
    end

    context "when the wallet uses a three-decimal currency" do
      let(:currency) { "KWD" }
      let(:rate_amount) { 0.001 }
      let(:credit_amount) { "1.0" }

      it "keeps a sub-cent but non-zero value as not rounding to zero" do
        expect(subject).to be(false)
      end
    end
  end

  context "when invoiceable is false" do
    let(:invoiceable) { false }

    context "with a simple wallet" do
      describe "#credit_amount" do
        it "returns the credit_amount" do
          expect(subject.credit_amount).to eq(credit_amount)
        end
      end

      describe "#amount" do
        it "returns the amount" do
          expect(subject.amount).to eq(1000)
        end
      end
    end

    context "with a low wallet rate_amount" do
      let(:rate_amount) { 0.001 }
      let(:credit_amount) { 1034 }

      describe "#credit_amount" do
        it "returns the credit_amount" do
          # The 1034 is not rounded here, as we're not invoicing the credit
          expect(subject.credit_amount).to eq(1034)
        end
      end

      describe "#amount" do
        it "returns the amount" do
          expect(subject.amount).to eq(1.03)
        end
      end
    end
  end
end
