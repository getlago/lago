# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::Entitlement do
  subject { build(:entitlement) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:feature).class_name("Entitlement::Feature")
      expect(subject).to belong_to(:plan).optional
      expect(subject).to belong_to(:subscription).optional
      expect(subject).to have_many(:values).class_name("Entitlement::EntitlementValue").dependent(:destroy)
    end
  end

  describe "validations" do
    describe "exactly_one_parent_present validation" do
      let(:organization) { create(:organization) }
      let(:feature) { create(:feature, organization:) }
      let(:plan) { create(:plan, organization:) }
      let(:subscription) { create(:subscription, organization:) }

      it "is valid when only plan_id is present" do
        entitlement = build(:entitlement, organization:, feature:, plan:, subscription: nil)
        expect(entitlement).to be_valid
      end

      it "is valid when only subscription is present" do
        entitlement = build(:entitlement, organization:, feature:, plan: nil, subscription:)
        expect(entitlement).to be_valid
      end

      it "is invalid when both plan_id and subscription are present" do
        entitlement = build(:entitlement, organization:, feature:, plan:, subscription:)
        expect(entitlement).not_to be_valid
        expect(entitlement.errors[:base]).to eq(["one_of_plan_or_subscription_required"])
      end

      it "is invalid when neither plan_id nor subscription are present" do
        entitlement = build(:entitlement, organization:, feature:, plan: nil, subscription: nil)
        expect(entitlement).not_to be_valid
        expect(entitlement.errors[:base]).to eq(["one_of_plan_or_subscription_required"])
      end
    end
  end
end
