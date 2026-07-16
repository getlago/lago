# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::AnrokIntegration do
  subject(:anrok_integration) { build(:anrok_integration) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:connection_id) }
  it { is_expected.to have_many(:error_details) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(anrok_integration).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe ".api_key" do
    it "assigns and retrieve an api_key" do
      anrok_integration.api_key = "123abc456"
      expect(anrok_integration.api_key).to eq("123abc456")
    end
  end

  describe ".connection_id" do
    it "assigns and retrieve a secret pair" do
      anrok_integration.connection_id = "connection_id"
      expect(anrok_integration.connection_id).to eq("connection_id")
    end
  end
end
