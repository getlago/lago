# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Taxes::Invoices::NegateService do
  subject(:service_call) { described_class.call(invoice:) }

  let(:integration) { create(:anrok_integration, organization:) }
  let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/anrok/negate_invoices" }
  let(:current_time) { Time.current }

  let(:integration_collection_mapping1) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:
    )
  end

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "anrok"
    }
  end

  let(:params) do
    [
      {
        "id" => invoice.id,
        "voided_id" => "#{invoice.id}_voided"
      }
    ]
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)

    integration_customer
    integration_collection_mapping1
  end

  describe "#call" do
    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when negate invoice sync is successful" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_negate.json")
          File.read(path)
        end

        it "returns invoice_id" do
          result = service_call

          expect(result).to be_success
          expect(result.invoice_id).to be_present
        end
      end

      context "when negate invoice sync is NOT successful" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
          File.read(path)
        end

        it "returns errors" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("taxDateTooFarInFuture")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.tax_provider_error",
              customer,
              provider: "anrok",
              provider_code: integration.code,
              provider_error: {
                message: "Service failure",
                error_code: "taxDateTooFarInFuture"
              }
            )
        end

        context "when the response contains an out of memory error" do
          let(:body) do
            {"succeededInvoices" => [], "failedInvoices" => [{"validation_errors" => "function_runtime_out_of_memory"}]}.to_json
          end

          it "raises OutOfMemoryError" do
            expect { service_call }.to raise_error(Integrations::Aggregator::OutOfMemoryError)
          end
        end

        context "when the response contains a server contention error" do
          let(:body) do
            {"succeededInvoices" => [], "failedInvoices" => [{"validation_errors" => "API limit exceeded"}]}.to_json
          end

          it "raises ServerContentionError" do
            expect { service_call }.to raise_error(Integrations::Aggregator::ServerContentionError)
          end
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
          expect(result.fees).to be(nil)
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("action_script_runtime_error")
        end
      end

      context "when it is a task in progress error" do
        let(:error_code) { 500 }
        let(:body) { {error: {code: "action_script_failure", message: "Task abc12345-1234-1234-1234-abc123456789 is in progress"}}.to_json }

        it "raises TaskInProgressError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::TaskInProgressError)
        end
      end

      context "when it is a task expired error" do
        let(:error_code) { 500 }
        let(:body) { {error: {code: "action_script_failure", message: "Task abc12345-1234-1234-1234-abc123456789 expired"}}.to_json }

        it "raises TaskExpiredError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::TaskExpiredError)
        end
      end

      context "when it is an orchestrator failure error" do
        let(:error_code) { 500 }
        let(:body) { {error: {code: "action_script_failure", message: "POST http://nango-orchestrator-svc.nango/v1/immediate failed"}}.to_json }

        it "raises OrchestratorFailureError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::OrchestratorFailureError)
        end
      end

      context "when a network timeout occurs" do
        let(:error_code) { 500 }

        before do
          allow(lago_client).to receive(:post_with_response).with(params, headers).and_raise(Net::ReadTimeout)
        end

        it "raises TimeoutError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::TimeoutError)
        end
      end
    end
  end
end
