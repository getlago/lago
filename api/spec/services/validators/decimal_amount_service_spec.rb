# frozen_string_literal: true

require "rails_helper"

RSpec.describe Validators::DecimalAmountService do
  subject(:decimal_amount_service) { described_class.new(amount) }

  describe ".valid_amount?" do
    let(:amount) { "15.00" }

    it "returns true" do
      expect(decimal_amount_service).to be_valid_amount
    end

    context "with zero amount" do
      let(:amount) { "0.00" }

      it "returns true" do
        expect(decimal_amount_service).to be_valid_amount
      end
    end

    context "with negative amount" do
      let(:amount) { "-15.00" }

      it "returns false" do
        expect(decimal_amount_service).not_to be_valid_amount
      end
    end

    context "with invalid amount" do
      let(:amount) { "foobar" }

      it "returns false" do
        expect(decimal_amount_service).not_to be_valid_amount
      end
    end

    context "with not string amount" do
      let(:amount) { 1234 }

      it "returns false" do
        expect(decimal_amount_service).not_to be_valid_amount
      end
    end
  end

  describe ".valid_positive_amount?" do
    let(:amount) { "1.00" }

    it "returns true" do
      expect(decimal_amount_service).to be_valid_positive_amount
    end

    context "with zero amount" do
      let(:amount) { "0.00" }

      it "returns false" do
        expect(decimal_amount_service).not_to be_valid_positive_amount
      end
    end

    context "with negative amount" do
      let(:amount) { "-1.00" }

      it "returns false" do
        expect(decimal_amount_service).not_to be_valid_positive_amount
      end
    end
  end
end
