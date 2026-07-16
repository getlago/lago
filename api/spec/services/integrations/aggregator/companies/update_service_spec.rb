# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Companies::UpdateService do
  subject(:service_call) { described_class.call(integration:, integration_customer:) }

  let(:service) { described_class.new(integration:, integration_customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/#{integration_type}/companies" }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => integration_type_key
    }
  end

  let(:customer_link) do
    url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

    URI.join(url, "/#{customer.organization.slug}/customer/", customer.id).to_s
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(service).to receive(:throttle!)
  end

  describe "#initialize" do
    let(:integration) { create(:hubspot_integration, organization:) }
    let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
    let(:integration_type) { "hubspot" }
    let(:integration_type_key) { "hubspot" }

    context "when integration customer is a company" do
      it "initializes the service without errors" do
        expect { described_class.new(integration:, integration_customer:) }.not_to raise_error
      end
    end

    context "when integration customer is an individual" do
      before do
        allow(integration_customer.customer).to receive(:customer_type_individual?).and_return(true)
      end

      it "raises an ArgumentError" do
        expect { described_class.new(integration:, integration_customer:) }
          .to raise_error(ArgumentError, "Integration customer is not a company")
      end
    end
  end

  describe "#call" do
    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }
      let(:code) { 200 }

      context "when response is a string" do
        let(:integration) { create(:hubspot_integration, organization:) }
        let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
        let(:integration_type) { "hubspot" }
        let(:integration_type_key) { "hubspot" }

        let(:params) do
          {
            "companyId" => integration_customer.external_customer_id,
            "input" => {
              "properties" => {
                "name" => customer.name,
                "domain" => anything,
                "lago_customer_id" => customer.id,
                "lago_customer_external_id" => customer.external_id,
                "lago_billing_email" => customer.email,
                "lago_tax_identification_number" => customer.tax_identification_number,
                "lago_customer_link" => anything
              }
            }
          }
        end

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/companies/success_string_response.json")
          File.read(path)
        end

        before do
          allow(lago_client).to receive(:put_with_response).with(params, headers).and_return(response)
          allow(response).to receive(:body).and_return(body)
        end

        it "returns contact id" do
          result = service_call

          expect(result).to be_success
          expect(result.contact_id).to eq("1")
        end

        it_behaves_like "throttles!", :hubspot
      end

      context "when response is a hash" do
        let(:integration) { create(:hubspot_integration, organization:) }
        let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
        let(:integration_type) { "hubspot" }
        let(:integration_type_key) { "hubspot" }

        let(:params) do
          {
            "companyId" => integration_customer.external_customer_id,
            "input" => {
              "properties" => {
                "name" => customer.name,
                "domain" => anything,
                "lago_customer_id" => customer.id,
                "lago_customer_external_id" => customer.external_id,
                "lago_billing_email" => customer.email,
                "lago_tax_identification_number" => customer.tax_identification_number,
                "lago_customer_link" => anything
              }
            }
          }
        end

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/companies/success_hash_response.json")
          File.read(path)
        end

        before do
          allow(lago_client).to receive(:put_with_response).with(params, headers).and_return(response)
          allow(response).to receive(:body).and_return(body)
        end

        it "returns contact id" do
          result = service_call

          expect(result).to be_success
          expect(result.contact_id).to eq("2e50c200-9a54-4a66-b241-1e75fb87373f")
        end

        it_behaves_like "throttles!", :hubspot
      end
    end

    context "when service call is not successful" do
      let(:integration) { create(:hubspot_integration, organization:) }
      let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
      let(:integration_type) { "hubspot" }
      let(:integration_type_key) { "hubspot" }

      let(:params) do
        {
          "companyId" => integration_customer.external_customer_id,
          "input" => {
            "properties" => {
              "name" => customer.name,
              "domain" => anything,
              "lago_customer_id" => customer.id,
              "lago_customer_external_id" => customer.external_id,
              "lago_billing_email" => customer.email,
              "lago_tax_identification_number" => customer.tax_identification_number,
              "lago_customer_link" => anything
            }
          }
        }
      end

      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
        File.read(path)
      end

      let(:http_error) { LagoHttpClient::HttpError.new(error_code, body, nil) }

      before do
        allow(lago_client).to receive(:put_with_response).with(params, headers).and_raise(http_error)
      end

      context "when it is a server error" do
        let(:error_code) { Faker::Number.between(from: 500, to: 599) }
        let(:code) { "action_script_runtime_error" }
        let(:message) { "submitFields: Missing a required argument: type" }

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
          File.read(path)
        end

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error.code).to eq("action_script_runtime_error")
          expect(result.error.message)
            .to eq("action_script_runtime_error: submitFields: Missing a required argument: type")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.crm_provider_error",
              customer,
              provider: "hubspot",
              provider_code: integration.code,
              provider_error: {
                message: "submitFields: Missing a required argument: type",
                error_code: "action_script_runtime_error"
              }
            )
        end

        it_behaves_like "throttles!", :hubspot
      end

      context "when it is a server payload error" do
        let(:error_code) { Faker::Number.between(from: 500, to: 599) }
        let(:code) { "TypeError" }
        let(:message) { "Please enter value(s) for: Company Name" }

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_payload_response.json")
          File.read(path)
        end

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error.code).to eq(code)
          expect(result.error.message).to eq("#{code}: #{message}")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.crm_provider_error",
              customer,
              provider: "hubspot",
              provider_code: integration.code,
              provider_error: {
                message:,
                error_code: code
              }
            )
        end

        it_behaves_like "throttles!", :hubspot
      end

      context "when it is a client error" do
        let(:error_code) { 404 }
        let(:code) { "invalid_secret_key_format" }
        let(:message) { "Authentication failed. The provided secret key is not a UUID v4." }

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_auth_response.json")
          File.read(path)
        end

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error.code).to eq(code)
          expect(result.error.message).to eq("#{code}: #{message}")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.crm_provider_error",
              customer,
              provider: "hubspot",
              provider_code: integration.code,
              provider_error: {
                message:,
                error_code: code
              }
            )
        end

        it_behaves_like "throttles!", :hubspot
      end
    end
  end
end
