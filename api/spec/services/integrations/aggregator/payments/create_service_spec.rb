# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Payments::CreateService do
  subject(:service_call) { described_class.call(payment:) }

  let(:service) { described_class.new(payment:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/netsuite/payments" }
  let(:payment) { create(:payment, payable: invoice) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:integration_invoice) { create(:integration_resource, syncable: invoice, integration:) }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "netsuite-tba"
    }
  end

  let(:params) do
    {
      "isDynamic" => true,
      "columns" => {
        "customer" => integration_customer.external_customer_id,
        "payment" => payment.amount_cents.div(100).to_f
      },
      "options" => {
        "ignoreMandatoryFields" => false
      },
      "type" => "customerpayment",
      "lines" => [
        {
          "lineItems" => [
            {
              "amount" => payment.amount_cents.div(100).to_f,
              "apply" => true,
              "doc" => integration_invoice.external_id
            }
          ],
          "sublistId" => "apply"
        }
      ]
    }
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)

    integration_customer
    integration.sync_payments = true
    integration.save!
    integration_invoice
    payment
  end

  describe "#call_async" do
    subject(:service_call_async) { described_class.new(payment:).call_async }

    context "when payment exists" do
      it "enqueues payment create job" do
        expect { service_call_async }.to enqueue_job(Integrations::Aggregator::Payments::CreateJob)
      end
    end

    context "when payment does not exist" do
      let(:payment) { nil }

      it "returns an error" do
        result = service_call_async

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("payment_not_found")
      end
    end
  end

  describe "#call" do
    context "when integration_payment exists" do
      let(:integration_payment) do
        create(:integration_resource, integration:, syncable: payment, resource_type: "payment")
      end

      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        integration_payment
      end

      it "returns result without making an API call" do
        expect(lago_client).not_to have_received(:post_with_response)
        result = service_call

        expect(result).to be_success
        expect(result.external_id).to be_nil
      end
    end

    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when response is a string" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/payments/success_string_response.json")
          File.read(path)
        end

        it "returns external id" do
          result = service_call

          expect(result).to be_success
          expect(result.external_id).to eq("999")
        end

        it "creates integration resource object" do
          expect { service_call }.to change(IntegrationResource, :count).by(1)

          integration_resource = IntegrationResource.order(created_at: :desc).first

          expect(integration_resource.syncable_id).to eq(payment.id)
          expect(integration_resource.syncable_type).to eq("Payment")
          expect(integration_resource.resource_type).to eq("payment")
        end

        it_behaves_like "throttles!", :netsuite, :xero
      end

      context "when response is a hash" do
        context "when payment is succesfully created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/payments/success_hash_response.json")
            File.read(path)
          end

          it "returns external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to eq("e68f6095-f8d2-4d7a-ac05-7bb919d0330e")
          end

          it "creates integration resource object" do
            expect { service_call }.to change(IntegrationResource, :count).by(1)

            integration_resource = IntegrationResource.order(created_at: :desc).first

            expect(integration_resource.syncable_id).to eq(payment.id)
            expect(integration_resource.syncable_type).to eq("Payment")
            expect(integration_resource.resource_type).to eq("payment")
          end

          it_behaves_like "throttles!", :netsuite, :xero
        end

        context "when payment is not created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/payments/failure_hash_response.json")
            File.read(path)
          end

          it "does not return external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to be(nil)
          end

          it "does not create integration resource object" do
            expect { service_call }.not_to change(IntegrationResource, :count)
          end

          it_behaves_like "throttles!", :netsuite, :xero
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
        let(:error_code) { 500 }

        it "returns an error" do
          expect do
            service_call
          end.to raise_error(http_error)
        end

        it "enqueues a SendWebhookJob" do
          expect { service_call }.to have_enqueued_job(SendWebhookJob).and raise_error(http_error)
        end
      end

      context "when it is a client error" do
        let(:error_code) { 400 }

        it "does not return an error" do
          expect { service_call }.not_to raise_error
        end

        it "returns result" do
          expect(service_call).to be_a(BaseService::Result)
        end

        it "enqueues a SendWebhookJob" do
          expect { service_call }.to have_enqueued_job(SendWebhookJob)
        end

        it_behaves_like "throttles!", :netsuite, :xero
      end
    end
  end
end
