# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::GenerateCodeService do
  subject(:result) { described_class.call(plan:, billable_metric:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:, code: "api_calls") }

  describe "#call" do
    context "when no charges exist for the plan" do
      it "generates code without suffix" do
        expect(result.code).to eq("api_calls")
      end
    end

    context "when a charge exists with the base code" do
      before do
        create(:standard_charge, plan:, billable_metric:, code: "api_calls")
      end

      it "generates code with suffix _2" do
        expect(result.code).to eq("api_calls_2")
      end
    end

    context "when charges exist with numeric suffixes" do
      before do
        create(:standard_charge, plan:, billable_metric:, code: "api_calls")
        create(:standard_charge, plan:, billable_metric:, code: "api_calls_2")
      end

      it "generates code with next available suffix" do
        expect(result.code).to eq("api_calls_3")
      end
    end

    context "when multiple charges exist with gaps in suffixes" do
      before do
        create(:standard_charge, plan:, billable_metric:, code: "api_calls")
        create(:standard_charge, plan:, billable_metric:, code: "api_calls_3")
        create(:standard_charge, plan:, billable_metric:, code: "api_calls_5")
      end

      it "generates code with suffix one greater than the maximum" do
        expect(result.code).to eq("api_calls_6")
      end
    end

    context "when charges exist with similar but non-matching prefixes" do
      before do
        other_billable_metric = create(:billable_metric, organization:, code: "api_calls_premium")
        create(:standard_charge, plan:, billable_metric: other_billable_metric, code: "api_calls_premium")
      end

      it "generates code without suffix" do
        expect(result.code).to eq("api_calls")
      end
    end

    context "when charges exist without numeric suffixes" do
      before do
        create(:standard_charge, plan:, billable_metric:, code: "api_calls_custom")
      end

      it "generates code without suffix" do
        expect(result.code).to eq("api_calls")
      end
    end

    context "when child charges exist with base code" do
      let(:parent_plan) { create(:plan, organization:) }
      let(:parent_charge) { create(:standard_charge, plan: parent_plan, billable_metric:, code: "api_calls") }

      before do
        create(:standard_charge, plan:, billable_metric:, code: "api_calls", parent: parent_charge)
      end

      it "ignores child charges and generates code without suffix" do
        expect(result.code).to eq("api_calls")
      end
    end
  end
end
