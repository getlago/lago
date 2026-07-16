# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Gocardless::Webhooks::MandateCreatedService do
  subject(:mandate_created_service) { described_class.new(payment_provider:, mandate_id:) }

  let(:organization) { create(:organization) }
  let(:payment_provider) { create(:gocardless_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:gocardless_customer) do
    create(:gocardless_customer, customer:, payment_provider:, provider_customer_id:)
  end

  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_mandates_service) { instance_double(GoCardlessPro::Services::MandatesService) }

  let(:mandate_id) { "index_ID_123" }
  let(:provider_customer_id) { "CU123456" }
  let(:mandate) do
    GoCardlessPro::Resources::Mandate.new(
      "id" => mandate_id,
      "scheme" => "bacs",
      "links" => {"customer" => provider_customer_id}
    )
  end

  describe "#call" do
    before do
      gocardless_customer

      allow(GoCardlessPro::Client).to receive(:new).and_return(gocardless_client)
      allow(gocardless_client).to receive(:mandates).and_return(gocardless_mandates_service)
      allow(gocardless_mandates_service).to receive(:get).with(mandate_id).and_return(mandate)
    end

    it "creates a payment method for the customer" do
      expect { mandate_created_service.call }.to change(PaymentMethod, :count).by(1)
    end

    it "returns a successful result with the payment method" do
      result = mandate_created_service.call

      expect(result).to be_success
      expect(result.payment_method).to be_present
      expect(result.payment_method.provider_method_id).to eq(mandate_id)
      expect(result.payment_method.payment_provider_customer).to eq(gocardless_customer)
    end

    it "updates the gocardless customer provider_mandate_id" do
      mandate_created_service.call

      expect(gocardless_customer.reload.provider_mandate_id).to eq(mandate_id)
    end

    context "when mandate fetch fails" do
      before do
        allow(gocardless_mandates_service).to receive(:get)
          .and_raise(GoCardlessPro::Error.new("code" => "not_found", "message" => "Mandate not found"))
      end

      it "does not create a payment method" do
        expect { mandate_created_service.call }.not_to change(PaymentMethod, :count)
      end

      it "returns a successful result without payment method" do
        result = mandate_created_service.call

        expect(result).to be_success
        expect(result.payment_method).to be_nil
      end
    end

    context "when gocardless customer is not found" do
      let(:mandate) do
        GoCardlessPro::Resources::Mandate.new(
          "id" => mandate_id,
          "scheme" => "bacs",
          "links" => {"customer" => "unknown_customer_id"}
        )
      end

      it "does not create a payment method" do
        expect { mandate_created_service.call }.not_to change(PaymentMethod, :count)
      end

      it "returns a successful result without payment method" do
        result = mandate_created_service.call

        expect(result).to be_success
        expect(result.payment_method).to be_nil
      end
    end
  end
end
