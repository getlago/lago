# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::EstimateInstant::PercentageService do
  subject { described_class.new(properties:, units:) }

  let(:properties) do
    {
      "rate" => rate,
      "fixed_amount" => fixed_amount,
      "per_transaction_max_amount" => per_transaction_max_amount,
      "per_transaction_min_amount" => per_transaction_min_amount
    }
  end
  let(:units) { 0 }
  let(:rate) { 0 }
  let(:fixed_amount) { nil }
  let(:per_transaction_max_amount) { nil }
  let(:per_transaction_min_amount) { nil }

  describe "call" do
    it "returns zero amounts" do
      result = subject.call
      expect(result.amount).to be_zero
      expect(result.units).to be_zero
    end

    context "when units is negative" do
      let(:units) { -1 }

      it "returns zero amounts" do
        result = subject.call
        expect(result.amount).to be_zero
        expect(result.units).to be_zero
      end
    end

    context "when units and rate are positive" do
      let(:units) { 20 }
      let(:rate) { 2.99 }

      it "returns the percentage amount" do
        result = subject.call
        expect(result.amount).to eq(0.598)
        expect(result.units).to eq(20)
      end

      context "when fixed_amount is configured" do
        let(:fixed_amount) { 10 }

        it "includes the fixed amount" do
          result = subject.call
          expect(result.amount).to eq(10.598)
          expect(result.units).to eq(20)
        end
      end

      context "when a maximum is set" do
        let(:per_transaction_max_amount) { 0.1 }

        it "returns the percentage amount capped at the max" do
          result = subject.call
          expect(result.amount).to eq(0.1)
          expect(result.units).to eq(20)
        end
      end

      context "when a minimum is set" do
        let(:per_transaction_min_amount) { 5.5 }

        it "returns the percentage amount and at least the min" do
          result = subject.call
          expect(result.amount).to eq(5.5)
          expect(result.units).to eq(20)
        end
      end
    end
  end

  context "with all combinations of testcases" do
    let(:test_cases) do
      # array consisting of units, rate, fixed_amount, max, min, expected_amount
      [
        [100, 2, nil, nil, nil, 2],
        [100, 0, nil, nil, nil, 0],
        [100, 0, 12, nil, nil, 12],
        [100, 0, 2, 15, 0, 2],
        [100, 15, 3, 2, 1, 2],
        [100, 15, 0, nil, 16, 16],
        [0, 12, 2, nil, nil, 2],
        [0, 12, 2, nil, 13, 13]
      ]
    end

    it "validates all testcases" do
      test_cases.each do |arr|
        expected_amount = arr.pop
        units, rate, fixed_amount, per_transaction_max_amount, per_transaction_min_amount = *arr
        properties = {
          "rate" => rate,
          "fixed_amount" => fixed_amount,
          "per_transaction_max_amount" => per_transaction_max_amount,
          "per_transaction_min_amount" => per_transaction_min_amount
        }
        expect(described_class.call(properties:, units:).amount).to eq(expected_amount)
      end
    end
  end
end
