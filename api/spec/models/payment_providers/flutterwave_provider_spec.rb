# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::FlutterwaveProvider do
  subject(:flutterwave_provider) { build(:flutterwave_provider) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:secret_key) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to allow_value(nil).for(:success_redirect_url) }
    it { is_expected.to allow_value("https://example.com/success").for(:success_redirect_url) }
    it { is_expected.not_to allow_value("invalid-url").for(:success_redirect_url) }
    it { is_expected.not_to allow_value("a" * 1025).for(:success_redirect_url) }

    it "validates uniqueness of the code" do
      expect(flutterwave_provider).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe "constants" do
    it "defines success redirect URL" do
      expect(described_class::SUCCESS_REDIRECT_URL).to eq("https://www.flutterwave.com/ng")
    end

    it "defines API URL" do
      expect(described_class::API_URL).to eq("https://api.flutterwave.com/v3")
    end

    it "defines processing statuses" do
      expect(described_class::PROCESSING_STATUSES).to eq(%w[pending])
    end

    it "defines success statuses" do
      expect(described_class::SUCCESS_STATUSES).to eq(%w[successful])
    end

    it "defines failed statuses" do
      expect(described_class::FAILED_STATUSES).to eq(%w[failed cancelled])
    end
  end

  describe "#payment_type" do
    it "returns flutterwave" do
      expect(flutterwave_provider.payment_type).to eq("flutterwave")
    end
  end

  describe "#api_url" do
    it "returns the API URL" do
      expect(flutterwave_provider.api_url).to eq("https://api.flutterwave.com/v3")
    end
  end

  describe "webhook_secret generation" do
    context "when creating a new provider" do
      it "generates a webhook secret" do
        provider = create(:flutterwave_provider)
        expect(provider.webhook_secret).to be_present
        expect(provider.webhook_secret.length).to eq(64)
      end

      it "generates different secrets for different providers" do
        provider1 = create(:flutterwave_provider)
        provider2 = create(:flutterwave_provider)
        expect(provider1.webhook_secret).not_to eq(provider2.webhook_secret)
      end

      it "does not override existing webhook secret" do
        existing_secret = "existing_secret"
        provider = described_class.new(
          organization: create(:organization),
          name: "Test Provider",
          code: "test_provider",
          secret_key: "test_key",
          webhook_secret: existing_secret
        )
        provider.save!
        expect(provider.reload.webhook_secret).to eq(existing_secret)
      end
    end
  end

  describe "FlutterwavePayment" do
    it "defines a data structure for payments" do
      payment = described_class::FlutterwavePayment.new(
        id: "12345",
        status: "successful",
        metadata: {amount: 1000}
      )

      expect(payment.id).to eq("12345")
      expect(payment.status).to eq("successful")
      expect(payment.metadata).to eq({amount: 1000})
    end
  end

  describe "secrets accessors" do
    it "provides access to secret_key through secrets" do
      provider = create(:flutterwave_provider, secret_key: "test_secret_key")
      expect(provider.secret_key).to eq("test_secret_key")
    end

    it "provides access to webhook_secret through secrets" do
      provider = create(:flutterwave_provider)
      expect(provider.webhook_secret).to be_present
    end
  end
end
