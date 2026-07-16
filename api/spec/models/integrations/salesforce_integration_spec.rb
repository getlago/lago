# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::SalesforceIntegration do
  subject(:salesforce_integration) { build(:salesforce_integration) }

  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:instance_id) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(salesforce_integration).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe "#instance_id" do
    it "assigns and retrieve a setting" do
      salesforce_integration.instance_id = "instance_id_1"
      expect(salesforce_integration.instance_id).to eq("instance_id_1")
    end
  end

  describe "#code" do
    it "returns salesforce" do
      expect(salesforce_integration.code).to eq("salesforce")
    end
  end
end
