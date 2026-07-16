# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::StripeProvider do
  subject(:stripe_provider) { build(:stripe_provider, attributes) }

  let(:attributes) {}

  it { is_expected.to validate_length_of(:success_redirect_url).is_at_most(1024).allow_nil }
  it { is_expected.to validate_presence_of(:name) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(stripe_provider).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe "secret_key" do
    it "assigns and retrieve a secret key" do
      stripe_provider.secret_key = "foo_bar"
      expect(stripe_provider.secret_key).to eq("foo_bar")
    end
  end

  describe "webhook_id" do
    it "assigns and retrieve a setting" do
      stripe_provider.webhook_id = "webhook_id"
      expect(stripe_provider.webhook_id).to eq("webhook_id")
    end
  end

  describe "webhook_secret" do
    it "assigns and retrieve a setting" do
      stripe_provider.webhook_secret = "secret"
      expect(stripe_provider.webhook_secret).to eq("secret")
    end
  end

  describe "#success_redirect_url" do
    let(:success_redirect_url) { Faker::Internet.url }

    before { stripe_provider.success_redirect_url = success_redirect_url }

    it "returns the url" do
      expect(stripe_provider.success_redirect_url).to eq success_redirect_url
    end
  end
end
