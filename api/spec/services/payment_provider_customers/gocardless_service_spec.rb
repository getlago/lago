# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::GocardlessService do
  subject(:gocardless_service) { described_class.new(gocardless_customer) }

  let(:customer) { create(:customer, organization:) }
  let(:gocardless_provider) { create(:gocardless_provider) }
  let(:organization) { gocardless_provider.organization }
  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_customers_service) { instance_double(GoCardlessPro::Services::CustomersService) }
  let(:gocardless_billing_request_service) { instance_double(GoCardlessPro::Services::BillingRequestsService) }
  let(:gocardless_billing_request_flow_service) { instance_double(GoCardlessPro::Services::BillingRequestFlowsService) }

  let(:gocardless_customer) do
    create(:gocardless_customer, customer:, provider_customer_id: nil)
  end

  describe ".create" do
    before do
      allow(GoCardlessPro::Client).to receive(:new)
        .and_return(gocardless_client)
      allow(gocardless_client).to receive(:customers)
        .and_return(gocardless_customers_service)
      allow(gocardless_customers_service).to receive(:create)
        .and_return(GoCardlessPro::Resources::Customer.new("id" => "123"))
    end

    context "when all customer details are present" do
      it "creates a customer with company_name, given_name, and family_name" do
        gocardless_service.create
        expect(gocardless_customers_service).to have_received(:create).with(
          hash_including(
            params: {
              email: customer.email,
              company_name: customer.name,
              given_name: customer.firstname,
              family_name: customer.lastname
            }
          )
        )
      end
    end

    it "creates the gocardless customer" do
      result = gocardless_service.create

      expect(gocardless_customers_service).to have_received(:create)
      expect(result.gocardless_customer.provider_customer_id).to eq("123")
    end

    it "delivers a success webhook" do
      gocardless_service.create

      expect(gocardless_customers_service).to have_received(:create)
      expect(SendWebhookJob).to have_been_enqueued
        .with("customer.payment_provider_created", customer)
    end

    it "triggers checkout job" do
      gocardless_service.create

      expect(gocardless_customers_service).to have_received(:create)
      expect(PaymentProviderCustomers::GocardlessCheckoutUrlJob).to have_been_enqueued
        .with(gocardless_customer)
    end

    context "when customer already have a gocardless customer id" do
      let(:gocardless_customer) do
        create(:gocardless_customer, customer:, provider_customer_id: "cus_123456")
      end

      it "does not call gocardless API" do
        gocardless_service.create

        expect(gocardless_customers_service).not_to have_received(:create)
      end
    end

    context "when failing to create the customer" do
      it "delivers an error webhook" do
        allow(GoCardlessPro::Client).to receive(:new)
          .and_raise(GoCardlessPro::ApiError.new({"message" => "error"}))

        expect { gocardless_service.create }
          .to raise_error(GoCardlessPro::ApiError)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "error",
              error_code: nil
            }
          )
      end
    end
  end

  describe "#update" do
    it "returns result" do
      expect(gocardless_service.update).to be_a(BaseService::Result)
    end
  end

  describe ".generate_checkout_url" do
    before do
      allow(GoCardlessPro::Client).to receive(:new)
        .and_return(gocardless_client)
      allow(gocardless_client).to receive(:billing_requests)
        .and_return(gocardless_billing_request_service)
      allow(gocardless_billing_request_service).to receive(:create)
        .and_return(GoCardlessPro::Resources::BillingRequest.new("id" => "123"))

      allow(gocardless_client).to receive(:billing_request_flows)
        .and_return(gocardless_billing_request_flow_service)
      allow(gocardless_billing_request_flow_service).to receive(:create)
        .and_return(GoCardlessPro::Resources::BillingRequestFlow.new("authorisation_url" => "https://example.com"))
    end

    it "receives billing request flow response" do
      gocardless_service.generate_checkout_url

      expect(gocardless_billing_request_service).to have_received(:create)
      expect(gocardless_billing_request_flow_service).to have_received(:create)
    end

    it "delivers a webhook with checkout url" do
      gocardless_service.generate_checkout_url

      expect(gocardless_billing_request_service).to have_received(:create)
      expect(gocardless_billing_request_flow_service).to have_received(:create)
      expect(SendWebhookJob).to have_been_enqueued
        .with("customer.checkout_url_generated", customer, checkout_url: "https://example.com")
    end
  end

  describe "#success_redirect_url" do
    subject(:success_redirect_url) { gocardless_service.__send__(:success_redirect_url) }

    context "when payment provider has success redirect url" do
      it "returns payment provider's success redirect url" do
        expect(success_redirect_url).to eq(gocardless_provider.success_redirect_url)
      end
    end

    context "when payment provider has no success redirect url" do
      let(:gocardless_provider) { create(:gocardless_provider, success_redirect_url: nil) }

      it "returns the default success redirect url" do
        expect(success_redirect_url).to eq(PaymentProviders::GocardlessProvider::SUCCESS_REDIRECT_URL)
      end
    end
  end
end
