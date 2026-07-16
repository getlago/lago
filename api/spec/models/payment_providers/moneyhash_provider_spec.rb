# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::MoneyhashProvider do
  subject(:moneyhash_provider) { build(:moneyhash_provider, attributes) }

  let(:attributes) {}

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:api_key) }
  it { is_expected.to validate_presence_of(:flow_id) }
  it { is_expected.to validate_length_of(:flow_id).is_at_most(20) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(moneyhash_provider).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe "#api_key" do
    let(:api_key) { SecureRandom.uuid }

    before { moneyhash_provider.api_key = api_key }

    it "returns the api key" do
      expect(moneyhash_provider.api_key).to eq api_key
    end
  end

  describe "#flow_id" do
    let(:flow_id) { "test_flow_id" }

    before { moneyhash_provider.flow_id = flow_id }

    it "returns the flow id" do
      expect(moneyhash_provider.flow_id).to eq flow_id
    end
  end

  describe ".api_base_url" do
    context "when in production environment" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it "returns production URL" do
        expect(described_class.api_base_url).to eq("https://web.moneyhash.io")
      end
    end

    context "when in non-production environment" do
      before do
        allow(Rails.env).to receive(:production?).and_return(false)
      end

      it "returns staging URL" do
        expect(described_class.api_base_url).to eq("https://staging-web.moneyhash.io")
      end
    end
  end

  describe "#webhook_end_point" do
    let(:organization_id) { SecureRandom.uuid }
    let(:code) { "test_code" }
    let(:lago_api_url) { "https://api.getlago.com" }

    before do
      moneyhash_provider.organization_id = organization_id
      moneyhash_provider.code = code
      allow(ENV).to receive(:[]).with("LAGO_API_URL").and_return(lago_api_url)
    end

    it "returns the correct webhook endpoint URL" do
      expected_url = "#{lago_api_url}/webhooks/moneyhash/#{organization_id}?code=#{code}"
      expect(moneyhash_provider.webhook_end_point.to_s).to eq(expected_url)
    end
  end
end
