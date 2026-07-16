# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::Feature::SubscriptionsCountQuery do
  subject { described_class.new(organization:, filters: {feature_ids:}) }

  let(:organization) { create(:organization) }

  let(:empty_plan) { create(:plan, organization:) }
  let(:plan1) { create(:plan, organization:) }
  let(:plan2) { create(:plan, organization:) }
  let(:plan3) { create(:plan, organization:, parent: plan2) }

  let(:feature1) { create(:feature, organization:) }
  let(:feature2) { create(:feature, organization:) }
  let(:feature3) { create(:feature, organization:) }
  let(:feature4) { create(:feature, organization:) }
  let(:feature5) { create(:feature, organization:) }

  let(:feature_ids) do
    [
      feature1.id,
      feature2.id,
      feature3.id,
      feature4.id,
      feature5.id
    ]
  end

  before do
    create(:subscription, organization:, plan: plan1)
    create(:subscription, :pending, organization:, plan: plan1)
    create(:subscription, :terminated, organization:, plan: plan1)

    create(:subscription, organization:, plan: plan2)
    create(:subscription, :pending, organization:, plan: plan2)
    create(:subscription, :canceled, organization:, plan: plan2)

    create(:subscription, organization:, plan: plan3)
    create(:subscription, :incomplete, organization:, plan: plan3)

    create(:entitlement, organization:, feature: feature2, plan: empty_plan)
    create(:entitlement, organization:, feature: feature3, plan: plan1)
    create(:entitlement, organization:, feature: feature4, plan: plan2)
    create(:entitlement, organization:, feature: feature5, plan: plan1)
    create(:entitlement, organization:, feature: feature5, plan: plan2)
  end

  describe "#call" do
    it "returns features subscriptions_count" do
      result = subject.call

      expect(result).to eq({
        feature3.id => 2,
        feature4.id => 3,
        feature5.id => 5
      })
    end
  end
end
