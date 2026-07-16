# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::GenerateCodeService do
  subject(:result) { described_class.call(plan:, add_on:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:, code: "setup_fee") }

  describe "#call" do
    context "when no fixed charges exist for the plan" do
      it "generates code without suffix" do
        expect(result.code).to eq("setup_fee")
      end
    end

    context "when a fixed charge exists with the base code" do
      before do
        create(:fixed_charge, plan:, add_on:, code: "setup_fee")
      end

      it "generates code with suffix _2" do
        expect(result.code).to eq("setup_fee_2")
      end
    end

    context "when fixed charges exist with numeric suffixes" do
      before do
        create(:fixed_charge, plan:, add_on:, code: "setup_fee")
        create(:fixed_charge, plan:, add_on:, code: "setup_fee_2")
      end

      it "generates code with next available suffix" do
        expect(result.code).to eq("setup_fee_3")
      end
    end

    context "when multiple fixed charges exist with gaps in suffixes" do
      before do
        create(:fixed_charge, plan:, add_on:, code: "setup_fee")
        create(:fixed_charge, plan:, add_on:, code: "setup_fee_3")
        create(:fixed_charge, plan:, add_on:, code: "setup_fee_5")
      end

      it "generates code with suffix one greater than the maximum" do
        expect(result.code).to eq("setup_fee_6")
      end
    end

    context "when fixed charges exist with similar but non-matching prefixes" do
      before do
        other_add_on = create(:add_on, organization:, code: "setup_fee_premium")
        create(:fixed_charge, plan:, add_on: other_add_on, code: "setup_fee_premium")
      end

      it "generates code without suffix" do
        expect(result.code).to eq("setup_fee")
      end
    end

    context "when fixed charges exist without numeric suffixes" do
      before do
        create(:fixed_charge, plan:, add_on:, code: "setup_fee_custom")
      end

      it "generates code without suffix" do
        expect(result.code).to eq("setup_fee")
      end
    end

    context "when child fixed charges exist with base code" do
      let(:parent_plan) { create(:plan, organization:) }
      let(:parent_fixed_charge) { create(:fixed_charge, plan: parent_plan, add_on:, code: "setup_fee") }

      before do
        create(:fixed_charge, plan:, add_on:, code: "setup_fee", parent: parent_fixed_charge)
      end

      it "ignores child fixed charges and generates code without suffix" do
        expect(result.code).to eq("setup_fee")
      end
    end
  end
end
