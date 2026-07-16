# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Hubspot::CreateCustomerAssociationService do
  subject(:service_call) { service.call }

  let(:service) { described_class.new(invoice:) }
  let(:integration) { create(:hubspot_integration, organization:, sync_invoices:) }
  let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/hubspot/association" }
  let(:invoice_file_url) { invoice.file_url }
  let(:due_date) { invoice.payment_due_date.strftime("%Y-%m-%d") }

  let(:invoice) do
    create(
      :invoice,
      status: "finalized",
      customer:,
      organization:,
      coupons_amount_cents: 2000,
      prepaid_credit_amount_cents: 4000,
      credit_notes_amount_cents: 6000,
      taxes_amount_cents: 8000
    )
  end

  let(:integration_invoice) { create(:integration_resource, syncable: invoice, integration:) }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "hubspot"
    }
  end

  let(:params) do
    service.__send__(:payload).customer_association_body
  end

  before do
    integration_customer
    integration_invoice

    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(lago_client).to receive(:put_with_response).with(params, headers)
  end

  describe "#call" do
    context "when integration.sync_invoices is false" do
      let(:sync_invoices) { false }

      it "returns result without making a request" do
        expect(service_call).to be_a(BaseService::Result)
      end
    end

    context "when integration.sync_invoices is true" do
      let(:sync_invoices) { true }

      context "when request is successful" do
        before do
          allow(service).to receive(:http_client).and_return(lago_client)
          allow(Integrations::Hubspot::Invoices::DeployObjectService).to receive(:call)
        end

        it "calls the DeployObjectService" do
          service_call
          expect(Integrations::Hubspot::Invoices::DeployObjectService).to have_received(:call).with(integration: integration)
        end

        it "returns result" do
          expect(service_call).to be_a(BaseService::Result)
        end

        it_behaves_like "throttles!", :hubspot
      end
    end
  end
end
