# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundingHelper do
  subject(:helper) { described_class }

  describe ".round_decimal_part" do
    it "rounds the decimal part to the specified significant figures" do
      expect(helper.round_decimal_part(123.456789123, 4)).to eq("123.4568")
    end

    it "rounds the decimal part to the default significant figures when not specified" do
      expect(helper.round_decimal_part(123.456789123)).to eq("123.456789")
    end

    it "returns the integer part as a string when there is no decimal part" do
      expect(helper.round_decimal_part(123)).to eq("123")
    end

    it "handles numbers with leading zeros in the decimal part" do
      expect(helper.round_decimal_part(123.0000456789)).to eq("123.000046")
    end

    it "handles very small decimal parts correctly" do
      expect(helper.round_decimal_part(123.000000000456789)).to eq("123")
    end

    it "handles very small decimal parts only correctly" do
      expect(helper.round_decimal_part(0.0000000009)).to eq("0.0000000009")
    end

    it "handles negative numbers correctly" do
      expect(helper.round_decimal_part(-123.456789123)).to eq("-123.456789")
    end

    it "handles zero correctly" do
      expect(helper.round_decimal_part(0)).to eq("0")
    end
  end
end
