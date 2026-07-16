# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AdyenService do
  subject(:adyen_service) { described_class.new(membership.user) }

  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:api_key) { "test_api_key_1" }
  let(:code) { "code_1" }
  let(:name) { "Name 1" }
  let(:merchant_account) { "LagoMerchant" }
  let(:success_redirect_url) { Faker::Internet.url }

  describe ".create_or_update" do
    it "creates an adyen provider" do
      expect do
        adyen_service.create_or_update(organization:, api_key:, code:, name:, merchant_account:, success_redirect_url:)
      end.to change(PaymentProviders::AdyenProvider, :count).by(1)
    end

    it_behaves_like "produces a security log", "integration.created" do
      before { adyen_service.create_or_update(organization:, api_key:, code:, name:, merchant_account:, success_redirect_url:) }
    end

    context "when code was changed" do
      let(:new_code) { "updated_code_1" }
      let(:adyen_customer) { create(:adyen_customer, payment_provider:, customer:) }
      let(:customer) { create(:customer, organization:) }

      let(:payment_provider) do
        create(
          :adyen_provider,
          organization:,
          code:,
          name:,
          api_key: "secret"
        )
      end

      before { adyen_customer }

      it "updates payment provider codes of all customers" do
        result = adyen_service.create_or_update(
          id: payment_provider.id,
          organization:,
          code: new_code,
          name:,
          api_key: "secret"
        )

        expect(result).to be_success
        expect(result.adyen_provider.customers.first.payment_provider_code).to eq(new_code)
      end
    end

    context "when organization already has an adyen provider" do
      let(:adyen_provider) do
        create(:adyen_provider, organization:, api_key: "api_key_789", code:)
      end

      before { adyen_provider }

      it "updates the existing provider" do
        result = adyen_service.create_or_update(
          organization:,
          api_key:,
          code:,
          name:,
          success_redirect_url:
        )

        expect(result).to be_success

        expect(result.adyen_provider.id).to eq(adyen_provider.id)
        expect(result.adyen_provider.api_key).to eq("test_api_key_1")
        expect(result.adyen_provider.code).to eq(code)
        expect(result.adyen_provider.name).to eq(name)
        expect(result.adyen_provider.success_redirect_url).to eq(success_redirect_url)
      end

      it_behaves_like "produces a security log", "integration.updated" do
        before do
          adyen_service.create_or_update(
            organization:,
            api_key:,
            code:,
            name:,
            success_redirect_url:
          )
        end
      end
    end

    context "with validation error" do
      let(:token) { nil }

      it "returns an error result" do
        result = adyen_service.create_or_update(
          organization:,
          api_key: nil,
          merchant_account: nil
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:api_key]).to eq(["value_is_mandatory"])
        expect(result.error.messages[:merchant_account]).to eq(["value_is_mandatory"])
      end
    end
  end
end
