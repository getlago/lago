# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionFeatureRemoval do
  subject { build(:subscription_feature_removal) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:subscription)
      expect(subject).to belong_to(:feature).class_name("Entitlement::Feature").optional
      expect(subject).to belong_to(:privilege).class_name("Entitlement::Privilege").optional
    end
  end
end
