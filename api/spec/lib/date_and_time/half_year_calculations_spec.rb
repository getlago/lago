# frozen_string_literal: true

require "rails_helper"

RSpec.describe DateAndTime::HalfYearCalculations do
  describe "#beginning_of_half_year" do
    it "returns January 1st for dates in the first half" do
      expect(Date.new(2025, 1, 15).beginning_of_half_year).to eq(Date.new(2025, 1, 1))
      expect(Date.new(2025, 6, 30).beginning_of_half_year).to eq(Date.new(2025, 1, 1))
    end

    it "returns July 1st for dates in the second half" do
      expect(Date.new(2025, 7, 1).beginning_of_half_year).to eq(Date.new(2025, 7, 1))
      expect(Date.new(2025, 12, 31).beginning_of_half_year).to eq(Date.new(2025, 7, 1))
    end

    it "works with Time and respects midnight" do
      t = Time.zone.parse("2025-08-19 14:35")
      expect(t.beginning_of_half_year).to eq(Time.zone.parse("2025-07-01 00:00:00"))
    end

    context "when date is on exact half-year boundaries" do
      it "returns Jan 1 for Jan 1" do
        expect(Date.new(2025, 1, 1).beginning_of_half_year).to eq(Date.new(2025, 1, 1))
      end

      it "returns Jul 1 for Jul 1" do
        expect(Date.new(2025, 7, 1).beginning_of_half_year).to eq(Date.new(2025, 7, 1))
      end
    end
  end

  describe "#end_of_half_year" do
    it "returns June 30th for first half-year" do
      expect(Date.new(2025, 3, 10).end_of_half_year).to eq(Date.new(2025, 6, 30))
    end

    it "returns December 31st for second half-year" do
      expect(Date.new(2025, 10, 5).end_of_half_year).to eq(Date.new(2025, 12, 31))
    end

    it "works with Time and respects end of day" do
      t = Time.zone.parse("2025-03-20 10:00")
      expect(t.end_of_half_year).to eq(Time.zone.parse("2025-06-30 23:59:59.999999999"))
    end

    context "when it is a leap year" do
      it "still returns June 30th for first half" do
        expect(Date.new(2024, 2, 29).end_of_half_year).to eq(Date.new(2024, 6, 30))
      end

      it "still returns December 31st for second half" do
        expect(Date.new(2024, 11, 15).end_of_half_year).to eq(Date.new(2024, 12, 31))
      end
    end

    context "when date is on exact half-year boundaries" do
      it "returns June 30 for June 30" do
        expect(Date.new(2025, 6, 30).end_of_half_year).to eq(Date.new(2025, 6, 30))
      end

      it "returns Dec 31 for Dec 31" do
        expect(Date.new(2025, 12, 31).end_of_half_year).to eq(Date.new(2025, 12, 31))
      end
    end
  end
end
