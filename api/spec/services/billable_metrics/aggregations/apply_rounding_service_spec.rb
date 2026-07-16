# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Aggregations::ApplyRoundingService do
  subject(:rounding_service) { described_class.new(billable_metric:, units:) }

  let(:rounding_function) { "round" }
  let(:rounding_precision) { 2 }

  let(:billable_metric) do
    create(:billable_metric, rounding_precision:, rounding_function:)
  end

  let(:units) { 123.456 }

  describe "#call" do
    let(:result) { rounding_service.call }

    context "with round function" do
      it "returns the rounded units" do
        expect(result.units).to eq(123.46)
      end

      context "without precision" do
        let(:rounding_precision) { nil }

        it "applies the rounding to the integer value" do
          expect(result.units).to eq(123)
        end
      end

      context "with negative precision" do
        let(:rounding_precision) { -2 }

        it "applies the rounding" do
          expect(result.units).to eq(100)
        end
      end
    end

    context "with ceil function" do
      let(:rounding_function) { "ceil" }

      it "returns the rounded units" do
        expect(result.units).to eq(123.46)
      end

      context "without precision" do
        let(:rounding_precision) { nil }

        it "applies the rounding to the integer value" do
          expect(result.units).to eq(124)
        end
      end

      context "with negative precision" do
        let(:rounding_precision) { -2 }

        it "applies the rounding" do
          expect(result.units).to eq(200)
        end
      end
    end

    context "with floor function" do
      let(:rounding_function) { "floor" }

      it "returns the rounded units" do
        expect(result.units).to eq(123.45)
      end

      context "without precision" do
        let(:rounding_precision) { nil }

        it "applies the rounding to the integer value" do
          expect(result.units).to eq(123)
        end
      end

      context "with negative precision" do
        let(:rounding_precision) { -2 }

        it "applies the rounding" do
          expect(result.units).to eq(100)
        end
      end
    end

    context "without rounding function" do
      let(:rounding_function) { nil }

      it "returns the units" do
        expect(result.units).to eq(units)
      end
    end
  end
end
