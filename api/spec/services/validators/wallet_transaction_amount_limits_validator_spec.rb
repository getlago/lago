# frozen_string_literal: true

require "rails_helper"

RSpec.describe Validators::WalletTransactionAmountLimitsValidator do
  let(:result) { BaseService::LegacyResult.new }
  let(:wallet) { create(:wallet, paid_top_up_min_amount_cents:, paid_top_up_max_amount_cents:) }
  let(:paid_top_up_min_amount_cents) { 5_00 }
  let(:paid_top_up_max_amount_cents) { 100_00 }
  let(:credits_amount) { "1.0" }
  let(:ignore_validation) { false }

  describe "#raise_if_invalid!" do
    context "when invalid" do
      subject { described_class.new(result, wallet:, credits_amount:, ignore_validation:).raise_if_invalid! }

      it { expect { subject }.to raise_error(BaseService::ValidationFailure) }
    end

    context "when valid" do
      subject { described_class.new(result, wallet:, credits_amount:, ignore_validation: true).raise_if_invalid! }

      it { expect { subject }.not_to raise_error }
    end
  end

  describe "#valid?" do
    subject { described_class.new(result, wallet:, credits_amount:, ignore_validation:).valid? }

    context "when ignore_validation is true" do
      let(:ignore_validation) { true }

      it { is_expected.to be true }
    end

    context "when wallet does not have limits" do
      let(:paid_top_up_min_amount_cents) { nil }
      let(:paid_top_up_max_amount_cents) { nil }

      it { is_expected.to be true }
    end

    context "when credits_amount is blank" do
      let(:credits_amount) { nil }

      it do
        expect(subject).to be false
        expect(result).to be_failure
        expect(result.error.messages[:paid_credits]).to eq(["invalid_amount"])
      end
    end

    context "when credits_amount is zero" do
      let(:credits_amount) { "0.00" }

      it do
        expect(subject).to be false
        expect(result).to be_failure
        expect(result.error.messages[:paid_credits]).to eq(["invalid_amount"])
      end
    end

    context "when credits_amount is less than min amount" do
      let(:credits_amount) { "4.99" }

      it do
        expect(subject).to be false
        expect(result).to be_failure
        expect(result.error.messages[:paid_credits]).to eq(["amount_below_minimum"])
      end
    end

    context "when credits_amount is more than max amount" do
      let(:credits_amount) { "100.1" }

      it do
        expect(subject).to be false
        expect(result).to be_failure
        expect(result.error.messages[:paid_credits]).to eq(["amount_above_maximum"])
      end
    end

    context "when credits_amount is equal to a limit" do
      let(:credits_amount) { "5" }
      let(:paid_top_up_max_amount_cents) { paid_top_up_min_amount_cents }

      it { is_expected.to be true }
    end

    context "when field_name is provided" do
      it "sets the field name in the result errors" do
        described_class.new(result, wallet:, credits_amount: "0", ignore_validation: false, field_name: :other_name).valid?
        expect(result.error.messages[:other_name]).to eq(["invalid_amount"])
      end
    end
  end
end
