# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Taxes::Avalara::FetchCompanyIdService do
  subject(:service_call) { described_class.call(integration:) }

  let(:integration) { create(:avalara_integration, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/avalara/companies" }
  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "avalara-sandbox"
    }
  end
  let(:params) do
    [
      {
        "company_code" => integration.company_code
      }
    ]
  end

  before do
    integration
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
  end

  describe "#call" do
    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when company fetch is successful" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/companies/success_response.json")
          File.read(path)
        end

        it "returns company id" do
          result = service_call

          expect(result).to be_success
          expect(result.company["id"]).to eq("DEFAULT-12345")
        end
      end

      context "when company fetch is NOT successful" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/companies/failed_response.json")
          File.read(path)
        end

        it "returns errors" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("company_not_found")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "integration.provider_error",
              integration,
              provider: "avalara",
              provider_code: integration.code,
              provider_error: {
                message: "Company cannot be found in Avalara based on the provided code",
                error_code: "company_not_found"
              }
            )
        end
      end
    end

    context "when service call is not successful" do
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
        File.read(path)
      end

      let(:http_error) { LagoHttpClient::HttpError.new(error_code, body, nil) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_raise(http_error)
      end

      context "when it is a server error" do
        let(:error_code) { Faker::Number.between(from: 500, to: 599) }

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("action_script_runtime_error")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "integration.provider_error",
              integration,
              provider: "avalara",
              provider_code: integration.code,
              provider_error: {
                message: "submitFields: Missing a required argument: type",
                error_code: "action_script_runtime_error"
              }
            )
        end
      end
    end
  end
end
