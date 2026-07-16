# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::EntitlementValue do
  subject { create(:entitlement_value) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:privilege).class_name("Entitlement::Privilege")
      expect(subject).to belong_to(:entitlement).class_name("Entitlement::Entitlement")
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:entitlement_privilege_id)
      expect(subject).to validate_presence_of(:entitlement_entitlement_id)
      expect(subject).to validate_presence_of(:value)
    end
  end
end
