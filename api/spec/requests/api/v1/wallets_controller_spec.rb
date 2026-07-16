# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::WalletsController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, currency: "EUR") }
  let(:subscription) { create(:subscription, customer:) }
  let(:expiration_at) { (Time.current + 1.year).iso8601 }
  let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }
  let(:payment_method) { create(:payment_method, organization:, customer:) }

  before { subscription }

  describe "POST /api/v1/wallets" do
    it_behaves_like "a wallet create endpoint" do
      subject do
        post_with_token(organization, "/api/v1/wallets", {wallet: create_params})
      end

      context "when params[:external_customer_id] is empty" do
        it "returns a validation error" do
          create_params.delete(:external_customer_id)

          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details][:customer]).to eq ["customer_not_found"]
        end
      end
    end

    it_behaves_like "a wallet create endpoint with billing_entity_id" do
      subject do
        post_with_token(organization, "/api/v1/wallets", {wallet: create_params})
      end
    end
  end

  describe "PUT /api/v1/wallets/:id" do
    it_behaves_like "a wallet update endpoint" do
      subject do
        put_with_token(
          organization,
          "/api/v1/wallets/#{id}",
          {wallet: update_params}
        )
      end

      let(:id) { wallet.id }
    end
  end

  describe "GET /api/v1/wallets/:id" do
    it_behaves_like "a wallet show endpoint" do
      subject { get_with_token(organization, "/api/v1/wallets/#{id}") }

      let(:id) { wallet.id }
    end
  end

  describe "DELETE /api/v1/wallets/:id" do
    it_behaves_like "a wallet terminate endpoint" do
      subject { delete_with_token(organization, "/api/v1/wallets/#{id}") }

      let(:id) { wallet.id }
    end
  end

  describe "GET /api/v1/wallets" do
    it_behaves_like "a wallet index endpoint" do
      subject do
        get_with_token(organization, "/api/v1/wallets?external_customer_id=#{external_id}", params)
      end

      context "when external_customer_id does not belong to the current organization" do
        let(:other_org_customer) { create(:customer) }
        let(:external_id) { other_org_customer.external_id }

        it "returns a not found error" do
          subject
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when filtering by billing_entity_codes" do
      let(:billing_entity_eu) { create(:billing_entity, organization:, code: "EU") }
      let(:billing_entity_us) { create(:billing_entity, organization:, code: "US") }
      let(:wallet_eu) { create(:wallet, customer:, billing_entity: billing_entity_eu) }
      let(:wallet_us) { create(:wallet, customer:, billing_entity: billing_entity_us) }

      before do
        wallet_eu
        wallet_us
      end

      it "returns only wallets under the requested billing entity" do
        get_with_token(organization, "/api/v1/wallets?billing_entity_codes[]=EU")

        expect(response).to have_http_status(:success)
        expect(json[:wallets].map { |w| w[:lago_id] }).to contain_exactly(wallet_eu.id)
      end

      context "when filtering by multiple billing_entity_codes" do
        it "returns wallets matching any of the provided codes" do
          get_with_token(organization, "/api/v1/wallets?billing_entity_codes[]=EU&billing_entity_codes[]=US")

          expect(response).to have_http_status(:success)
          expect(json[:wallets].map { |w| w[:lago_id] }).to contain_exactly(wallet_eu.id, wallet_us.id)
        end
      end

      context "when one of the billing_entity_codes is unknown" do
        it "returns a not found error" do
          get_with_token(organization, "/api/v1/wallets?billing_entity_codes[]=EU&billing_entity_codes[]=BOGUS")

          expect(response).to be_not_found_error("billing_entity")
        end
      end
    end
  end
end
