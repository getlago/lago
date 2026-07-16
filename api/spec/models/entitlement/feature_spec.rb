# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::Feature do
  subject { build(:feature) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to have_many(:privileges).class_name("Entitlement::Privilege").dependent(:destroy)
      expect(subject).to have_many(:entitlements).class_name("Entitlement::Entitlement").dependent(:destroy)
      expect(subject).to have_many(:entitlement_values).through(:entitlements).source(:values).class_name("Entitlement::EntitlementValue").dependent(:destroy)
      expect(subject).to have_many(:plans).through(:entitlements)
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:code)
      expect(subject).to validate_length_of(:code).is_at_most(255)
      expect(subject).to validate_length_of(:name).is_at_most(255)
      expect(subject).to validate_length_of(:description).is_at_most(600)
    end
  end

  describe "#subscriptions_count" do
    context "when subscriptions_count is not preloaded" do
      it "calculates the number of subscriptions" do
        expect(subject.subscriptions_count).to eq(0)
        entitlement = create(:entitlement, feature: subject)
        create(:subscription, plan: entitlement.plan)
        create(:subscription, :pending, plan: entitlement.plan)
        create(:subscription, :terminated, plan: entitlement.plan)
        create(:subscription, :canceled, plan: entitlement.plan)
        expect(subject.subscriptions_count).to eq(2)
        create(:subscription, plan: create(:plan, parent: entitlement.plan))
        create(:subscription, :pending, plan: create(:plan, parent: entitlement.plan))
        create(:subscription, :terminated, plan: create(:plan, parent: entitlement.plan))
        create(:subscription, :canceled, plan: create(:plan, parent: entitlement.plan))
        expect(subject.subscriptions_count).to eq(4)
      end
    end

    context "when subscriptions_count is preloaded" do
      before { subject.subscriptions_count = 100 }

      it "returns the preloaded value" do
        expect(subject.subscriptions_count).to eq(100)
      end
    end
  end

  describe ".preload_subscriptions_count" do
    subject { described_class.preload_subscriptions_count(organization, features) }

    let(:organization) { build(:organization) }

    let(:feature1) { build_stubbed(:feature, organization:) }
    let(:feature2) { build_stubbed(:feature, organization:) }
    let(:feature3) { build_stubbed(:feature, organization:) }

    let(:features) { [feature1, feature2, feature3] }

    let(:subscriptions_count) do
      {
        feature2.id => 5,
        feature3.id => 10
      }
    end

    before do
      allow(Entitlement::Feature::SubscriptionsCountQuery).to receive(:call).and_return(subscriptions_count)
    end

    it "preloads subscriptions_count values and sets them to features" do
      subject

      expect(feature1.subscriptions_count).to eq(0)
      expect(feature2.subscriptions_count).to eq(5)
      expect(feature3.subscriptions_count).to eq(10)
    end
  end
end
