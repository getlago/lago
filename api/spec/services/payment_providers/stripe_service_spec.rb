# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::StripeService do
  subject(:stripe_service) { described_class.new(membership.user) }

  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:code) { "code_1" }
  let(:name) { "Name 1" }
  let(:public_key) { SecureRandom.uuid }
  let(:secret_key) { SecureRandom.uuid }
  let(:success_redirect_url) { Faker::Internet.url }

  describe ".create_or_update" do
    it "creates a stripe provider" do
      expect do
        result = stripe_service.create_or_update(
          organization_id: organization.id,
          secret_key:,
          code:,
          name:,
          success_redirect_url:,
          supports_3ds: true
        )

        expect(PaymentProviders::Stripe::RegisterWebhookJob).to have_been_enqueued
          .with(result.stripe_provider)
        expect(result.stripe_provider.supports_3ds).to be(true)
      end.to change(PaymentProviders::StripeProvider, :count).by(1)
    end

    it_behaves_like "produces a security log", "integration.created" do
      before do
        stripe_service.create_or_update(
          organization_id: organization.id,
          secret_key:,
          code:,
          name:,
          success_redirect_url:,
          supports_3ds: true
        )
      end
    end

    context "when code was changed" do
      let(:new_code) { "updated_code_2" }
      let(:stripe_customer) { create(:stripe_customer, payment_provider:, customer:) }
      let(:customer) { create(:customer, organization:) }

      let(:payment_provider) do
        create(
          :stripe_provider,
          organization:,
          code:,
          name:,
          secret_key: "secret"
        )
      end

      before { stripe_customer }

      it "updates payment provider codes of all customers" do
        result = stripe_service.create_or_update(
          id: payment_provider.id,
          organization_id: organization.id,
          code: new_code,
          name:,
          secret_key: "secret"
        )

        expect(result).to be_success
        expect(result.stripe_provider.customers.first.payment_provider_code).to eq(new_code)
      end
    end

    context "when organization already have a stripe provider" do
      let(:stripe_provider) do
        create(
          :stripe_provider,
          organization:,
          code:,
          name:,
          webhook_id: "we_123456",
          secret_key: "secret"
        )
      end

      before do
        stripe_provider
      end

      it "updates the existing provider" do
        result = stripe_service.create_or_update(
          organization_id: organization.id,
          secret_key: "new_key",
          code:,
          name:,
          success_redirect_url:
        )

        expect(result).to be_success

        expect(result.stripe_provider.id).to eq(stripe_provider.id)
        expect(result.stripe_provider.secret_key).to eq("secret")
        expect(result.stripe_provider.code).to eq(code)
        expect(result.stripe_provider.name).to eq(name)
        expect(result.stripe_provider.success_redirect_url).to eq(success_redirect_url)

        expect(PaymentProviders::Stripe::RegisterWebhookJob).not_to have_been_enqueued
      end

      it_behaves_like "produces a security log", "integration.updated" do
        before do
          stripe_service.create_or_update(
            organization_id: organization.id,
            secret_key: "new_key",
            code:,
            name:,
            success_redirect_url:
          )
        end
      end
    end

    context "with validation error" do
      it "returns an error result" do
        result = stripe_service.create_or_update(
          organization_id: organization.id,
          secret_key: nil
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:secret_key]).to eq(["value_is_mandatory"])
      end
    end
  end
end
