# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::ReconcileService do
  subject(:service_call) { described_class.call(invoice:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
  let(:invoice) { create(:invoice, customer:, organization:, number: "INV-001") }

  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/netsuite/invoices/by-tranid" }
  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "netsuite-tba"
    }
  end
  let(:request_body) { {tranid: invoice.number} }

  before do
    integration_customer
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
  end

  describe "#call" do
    context "when the invoice is found upstream" do
      let(:service) { described_class.new(invoice:) }

      before do
        allow(lago_client).to receive(:get).with(headers:, body: request_body, content_type: "application/json").and_return("12345")
      end

      it_behaves_like "throttles!", :netsuite

      it "returns a successful result" do
        expect(service_call).to be_success
      end

      it "returns the external_id on the result" do
        expect(service_call.external_id).to eq("12345")
      end

      it "creates an IntegrationResource with the returned external_id" do
        expect { service_call }.to change(IntegrationResource, :count).by(1)

        expect(service_call.integration_resource).to have_attributes(
          external_id: "12345",
          syncable_id: invoice.id,
          syncable_type: "Invoice",
          resource_type: "invoice",
          integration_id: integration.id,
          organization_id: integration.organization_id
        )
      end
    end

    context "when the invoice is not found upstream" do
      let(:service) { described_class.new(invoice:) }

      before do
        allow(lago_client).to receive(:get).with(headers:, body: request_body, content_type: "application/json").and_return(nil)
      end

      it_behaves_like "throttles!", :netsuite

      it "returns a successful result" do
        expect(service_call).to be_success
      end

      it "does not return the external_id on the result" do
        expect(service_call.external_id).to be_nil
      end

      it "does not create an IntegrationResource" do
        expect { service_call }.not_to change(IntegrationResource, :count)
      end
    end

    context "when an IntegrationResource already exists for the invoice" do
      before do
        create(:integration_resource, integration:, syncable: invoice, resource_type: :invoice)
        allow(lago_client).to receive(:get)
      end

      it "does not call the HTTP client" do
        service_call
        expect(lago_client).not_to have_received(:get)
      end

      it "returns a successful result" do
        expect(service_call).to be_success
      end

      it "does not return the external_id on the result" do
        expect(service_call.external_id).to be_nil
      end

      it "does not create a duplicate IntegrationResource" do
        expect { service_call }.not_to change(IntegrationResource, :count)
      end
    end

    context "when the integration is not NetSuite" do
      let(:integration) { create(:xero_integration, organization:) }
      let(:integration_customer) { create(:xero_customer, integration:, customer:) }

      before { allow(lago_client).to receive(:get) }

      it "does not call the HTTP client" do
        service_call
        expect(lago_client).not_to have_received(:get)
      end

      it "returns a successful result" do
        expect(service_call).to be_success
      end

      it "does not return the external_id on the result" do
        expect(service_call.external_id).to be_nil
      end
    end

    context "when the customer has no accounting integration" do
      let(:integration_customer) { nil }

      it "returns a successful result without making an HTTP call" do
        result = service_call

        expect(result).to be_success
        expect(result.external_id).to be_nil
      end
    end

    context "when the HTTP call raises an error" do
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
        File.read(path)
      end
      let(:http_error) { LagoHttpClient::HttpError.new(error_code, body, nil) }

      before do
        allow(lago_client).to receive(:get).with(headers:, body: request_body, content_type: "application/json").and_raise(http_error)
      end

      context "with a server error" do
        let(:error_code) { 500 }

        it "re-raises the error so the job retries" do
          expect { service_call }.to raise_error(http_error)
        end

        it "does not create an IntegrationResource" do
          expect { service_call }.to raise_error(http_error)
          expect(IntegrationResource.count).to eq(0)
        end
      end

      context "with a client error" do
        let(:error_code) { 400 }

        it "re-raises the error so the job retries" do
          expect { service_call }.to raise_error(http_error)
        end

        it "does not create an IntegrationResource" do
          expect { service_call }.to raise_error(http_error)
          expect(IntegrationResource.count).to eq(0)
        end
      end
    end

    context "when the HTTP call returns a request limit error" do
      let(:body) { '{"type":"SSS_REQUEST_LIMIT_EXCEEDED"}' }
      let(:http_error) { LagoHttpClient::HttpError.new(429, body, nil) }

      before do
        allow(lago_client).to receive(:get).with(headers:, body: request_body, content_type: "application/json").and_raise(http_error)
      end

      it "raises a RequestLimitError" do
        expect { service_call }.to raise_error(Integrations::Aggregator::RequestLimitError)
      end
    end
  end
end
