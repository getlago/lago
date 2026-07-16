# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::GocardlessService do
  subject(:gocardless_service) { described_class.new(membership.user) }

  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:access_code) { "1234567!abc" }
  let(:code) { "code_1" }
  let(:name) { "Name 1" }
  let(:oauth_client) { instance_double(OAuth2::Client) }
  let(:auth_code_strategy) { instance_double(OAuth2::Strategy::AuthCode) }
  let(:access_token) { instance_double(OAuth2::AccessToken) }
  let(:token) { "access_token_554" }
  let(:success_redirect_url) { Faker::Internet.url }

  before do
    allow(OAuth2::Client).to receive(:new)
      .and_return(oauth_client)
    allow(oauth_client).to receive(:auth_code)
      .and_return(auth_code_strategy)
    allow(auth_code_strategy).to receive(:get_token)
      .and_return(access_token)
    allow(access_token).to receive(:token)
      .and_return(token)
  end

  describe ".create_or_update" do
    it "creates a gocardless provider" do
      expect do
        gocardless_service.create_or_update(
          organization:,
          access_code:,
          code:,
          name:,
          success_redirect_url:
        )
      end.to change(PaymentProviders::GocardlessProvider, :count).by(1)
    end

    it_behaves_like "produces a security log", "integration.created" do
      before do
        gocardless_service.create_or_update(
          organization:,
          access_code:,
          code:,
          name:,
          success_redirect_url:
        )
      end
    end

    context "when code was changed" do
      let(:new_code) { "updated_code_3" }
      let(:gocardless_customer) { create(:gocardless_customer, payment_provider:, customer:) }
      let(:customer) { create(:customer, organization:) }

      let(:payment_provider) do
        create(
          :gocardless_provider,
          organization:,
          code:,
          name:,
          access_token: "secret"
        )
      end

      before { gocardless_customer }

      it "updates payment provider codes of all customers" do
        result = gocardless_service.create_or_update(
          id: payment_provider.id,
          organization:,
          code: new_code,
          name:,
          access_token: "secret"
        )

        expect(result).to be_success
        expect(result.gocardless_provider.customers.first.payment_provider_code).to eq(new_code)
      end
    end

    context "when organization already have a gocardless provider" do
      let(:gocardless_provider) do
        create(:gocardless_provider, organization:, access_token: "access_token_123", code:)
      end

      before { gocardless_provider }

      it "updates the existing provider" do
        result = gocardless_service.create_or_update(
          organization:,
          access_code:,
          code:,
          name:,
          success_redirect_url:
        )

        expect(result).to be_success

        expect(result.gocardless_provider.id).to eq(gocardless_provider.id)
        expect(result.gocardless_provider.access_token).to eq("access_token_554")
        expect(result.gocardless_provider.code).to eq(code)
        expect(result.gocardless_provider.name).to eq(name)
        expect(result.gocardless_provider.success_redirect_url).to eq(success_redirect_url)
      end

      it_behaves_like "produces a security log", "integration.updated" do
        before do
          gocardless_service.create_or_update(
            organization:,
            access_code:,
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
        result = gocardless_service.create_or_update(
          organization:,
          access_code:
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:access_token]).to eq(["value_is_mandatory"])
      end
    end
  end
end
