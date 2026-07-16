# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageThresholds::UpdateService, premium: true do
  subject(:result) { described_class.call(model:, usage_thresholds_params:, partial:) }

  let(:organization) { create(:organization, premium_integrations: ["progressive_billing"]) }
  let(:model) { create(:plan, organization:) }

  before do
    allow(LifetimeUsages::FlagRefreshFromPlanUpdateJob).to receive(:perform_after_commit)
  end

  # Helper to build threshold attributes for comparison
  def threshold_attrs(thresholds)
    thresholds.map { |t| {amount_cents: t.amount_cents, threshold_display_name: t.threshold_display_name, recurring: t.recurring} }
  end

  describe "threshold updates" do
    # rubocop:disable Layout/LineLength
    test_cases = [
      {
        description: "creates new threshold when none exist",
        partial: false,
        existing: [],
        params: [{amount_cents: 100, threshold_display_name: "First"}],
        expected: [{amount_cents: 100, threshold_display_name: "First", recurring: false}]
      },
      {
        description: "updates existing threshold matched by amount_cents",
        partial: false,
        existing: [{amount_cents: 100, threshold_display_name: "Old Name"}],
        params: [{amount_cents: 100, threshold_display_name: "New Name"}],
        expected: [{amount_cents: 100, threshold_display_name: "New Name", recurring: false}]
      },
      {
        description: "removes thresholds not in params (full update)",
        partial: false,
        existing: [
          {amount_cents: 100, threshold_display_name: "Keep"},
          {amount_cents: 200, threshold_display_name: "Remove"}
        ],
        params: [{amount_cents: 100, threshold_display_name: "Keep"}],
        expected: [{amount_cents: 100, threshold_display_name: "Keep", recurring: false}]
      },
      {
        description: "creates multiple thresholds",
        partial: false,
        existing: [],
        params: [
          {amount_cents: 100, threshold_display_name: "First"},
          {amount_cents: 200, threshold_display_name: "Second"}
        ],
        expected: [
          {amount_cents: 100, threshold_display_name: "First", recurring: false},
          {amount_cents: 200, threshold_display_name: "Second", recurring: false}
        ]
      },
      {
        description: "handles recurring threshold update",
        partial: false,
        existing: [{amount_cents: 100, threshold_display_name: "Old", recurring: true}],
        params: [{amount_cents: 200, threshold_display_name: "New", recurring: true}],
        expected: [{amount_cents: 200, threshold_display_name: "New", recurring: true}]
      },
      {
        description: "clears all thresholds when params empty",
        partial: false,
        existing: [{amount_cents: 100, threshold_display_name: "Remove Me"}],
        params: [],
        expected: []
      },
      {
        description: "partial add a new item",
        partial: true,
        existing: [
          {amount_cents: 100, recurring: false},
          {amount_cents: 150, recurring: false}
        ],
        params: [{amount_cents: 333}],
        expected: [
          {amount_cents: 100, threshold_display_name: nil, recurring: false},
          {amount_cents: 150, threshold_display_name: nil, recurring: false},
          {amount_cents: 333, threshold_display_name: nil, recurring: false}
        ]
      },
      {
        description: "partial creates s recurring threshold update even if using same amount",
        partial: true,
        existing: [
          {amount_cents: 100, recurring: false},
          {amount_cents: 150, recurring: false}
        ],
        params: [{amount_cents: 100, threshold_display_name: "New", recurring: true}],
        expected: [
          {amount_cents: 100, threshold_display_name: nil, recurring: false},
          {amount_cents: 150, threshold_display_name: nil, recurring: false},
          {amount_cents: 100, threshold_display_name: "New", recurring: true}
        ]
      },
      {
        description: "partial update of non recurring threshold does not clear existing recurring threshold",
        partial: true,
        existing: [
          {amount_cents: 100, recurring: false},
          {amount_cents: 100, recurring: true}
        ],
        params: [{amount_cents: 100, threshold_display_name: "New", recurring: true}],
        expected: [
          {amount_cents: 100, threshold_display_name: nil, recurring: false},
          {amount_cents: 100, threshold_display_name: "New", recurring: true}
        ]
      },
      {
        description: "partial update of non recurring threshold does not clear existing recurring threshold",
        partial: true,
        existing: [
          {amount_cents: 100, recurring: false},
          {amount_cents: 100, recurring: true}
        ],
        params: [{amount_cents: 100, threshold_display_name: "New"}],
        expected: [
          {amount_cents: 100, threshold_display_name: "New", recurring: false},
          {amount_cents: 100, threshold_display_name: nil, recurring: true}
        ]
      }
    ]
    # rubocop:enable Layout/LineLength

    test_cases.each do |tc|
      context "when #{tc[:description]}" do
        let(:partial) { tc[:partial] }
        let(:usage_thresholds_params) { tc[:params] }

        before do
          tc[:existing].each do |attrs|
            create(:usage_threshold, plan: model, organization:, threshold_display_name: nil, **attrs)
          end
        end

        it do
          expect(result).to be_success
          expect(threshold_attrs(model.usage_thresholds.reload)).to match_array(tc[:expected])
        end
      end
    end
  end
end
