# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageThresholds::OverrideService do
  subject(:override_service) { described_class.new(usage_thresholds_params:, new_plan: plan) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  describe "#call" do
    let(:threshold) { create(:usage_threshold, plan:) }
    let(:plan) { create(:plan, organization:) }

    let(:usage_thresholds_params) do
      [
        {
          plan_id: plan.id,
          threshold_display_name: "Overridden threshold",
          amount_cents: 1000
        }
      ]
    end

    before { threshold }

    it "creates a threshold based on the given threshold" do
      expect { override_service.call }.to change(UsageThreshold, :count).by(1)

      threshold = UsageThreshold.order(:created_at).last

      expect(threshold).to have_attributes(
        recurring: threshold.recurring,
        # Overridden attributes
        plan_id: plan.id,
        threshold_display_name: "Overridden threshold",
        amount_cents: 1000
      )
    end

    context "when thresholds are not unique" do
      let(:usage_thresholds_params) do
        [
          {
            plan_id: plan.id,
            threshold_display_name: "Overridden threshold",
            amount_cents: 1000
          },
          {
            plan_id: plan.id,
            threshold_display_name: "",
            amount_cents: 1000
          }
        ]
      end

      it do
        result = override_service.call
        expect(result).to be_failure
        expect(result.error.messages[:amount_cents]).to contain_exactly("value_already_exist")
      end
    end
  end
end
