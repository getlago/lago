# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::EstimateInstant::StandardService do
  subject { described_class.new(properties:, units:) }

  let(:properties) do
    {
      "amount" => amount
    }
  end

  let(:amount) { nil }
  let(:units) { 0 }

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

    context "when units and amount are positive" do
      let(:units) { 20 }
      let(:amount) { "20" }

      it "returns the percentage amount" do
        result = subject.call
        expect(result.amount).to eq(400)
        expect(result.units).to eq(20)
      end
    end
  end
end
