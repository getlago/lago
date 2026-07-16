# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::CashfreeService do
  subject(:cashfree_service) { described_class.new(membership.user) }

  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:code) { "code_1" }
  let(:name) { "Name 1" }
  let(:client_id) { "123456_abc" }
  let(:client_secret) { "cfsk_ma_prod_abc_123456" }
  let(:success_redirect_url) { Faker::Internet.url }

  describe ".create_or_update" do
    it "creates a cashfree provider" do
      expect do
        cashfree_service.create_or_update(
          organization:,
          code:,
          name:,
          client_id:,
          client_secret:,
          success_redirect_url:
        )
      end.to change(PaymentProviders::CashfreeProvider, :count).by(1)
    end

    it_behaves_like "produces a security log", "integration.created" do
      before do
        cashfree_service.create_or_update(
          organization:,
          code:,
          name:,
          client_id:,
          client_secret:,
          success_redirect_url:
        )
      end
    end

    context "when code was changed" do
      let(:new_code) { "updated_code_1" }
      let(:cashfree_customer) { create(:cashfree_customer, payment_provider:, customer:) }
      let(:customer) { create(:customer, organization:) }

      let(:payment_provider) do
        create(
          :cashfree_provider,
          organization:,
          code:,
          name:,
          client_secret: "secret"
        )
      end

      before { cashfree_customer }

      it "updates payment provider codes of all customers" do
        result = cashfree_service.create_or_update(
          id: payment_provider.id,
          organization:,
          code: new_code,
          name:,
          client_secret: "secret"
        )

        expect(result).to be_success
        expect(result.cashfree_provider.customers.first.payment_provider_code).to eq(new_code)
      end
    end

    context "when organization already have a cashfree provider" do
      let(:cashfree_provider) do
        create(:cashfree_provider, organization:, client_id: "123456_abc_old", client_secret: "cfsk_ma_prod_abc_123456_old", code:)
      end

      before { cashfree_provider }

      it "updates the existing provider" do
        result = cashfree_service.create_or_update(
          organization:,
          code:,
          name:,
          client_id:,
          client_secret:,
          success_redirect_url:
        )

        expect(result).to be_success

        expect(result.cashfree_provider.id).to eq(cashfree_provider.id)
        expect(result.cashfree_provider.client_id).to eq("123456_abc")
        expect(result.cashfree_provider.client_secret).to eq("cfsk_ma_prod_abc_123456")
        expect(result.cashfree_provider.code).to eq(code)
        expect(result.cashfree_provider.name).to eq(name)
        expect(result.cashfree_provider.success_redirect_url).to eq(success_redirect_url)
      end

      it_behaves_like "produces a security log", "integration.updated" do
        before do
          cashfree_service.create_or_update(
            organization:,
            code:,
            name:,
            client_id:,
            client_secret:,
            success_redirect_url:
          )
        end
      end
    end

    context "with validation error" do
      let(:token) { nil }

      it "returns an error result" do
        result = cashfree_service.create_or_update(
          organization:
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:client_id]).to eq(["value_is_mandatory"])
        expect(result.error.messages[:client_secret]).to eq(["value_is_mandatory"])
      end
    end
  end
end
