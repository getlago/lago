# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizeAllJob do
  subject(:finalize_all_job) { described_class }

  let(:finalize_batch_service) { instance_double(Invoices::FinalizeBatchService) }
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, :draft, organization:) }

  context "when succesfully fetching taxes" do
    before do
      allow(Invoices::FinalizeBatchService).to receive(:new).and_return(finalize_batch_service)
      allow(finalize_batch_service).to receive(:call).and_return(result)
    end

    it "calls the retry batch service" do
      finalize_all_job.perform_now(organization:, invoice_ids: [invoice.id])

      expect(Invoices::FinalizeBatchService).to have_received(:new)
      expect(finalize_batch_service).to have_received(:call)
    end
  end

  context "when there was a tax fetching error in FinalizeBatch service" do
    let(:integration_customer) { create(:anrok_customer, customer: invoice.customer) }
    let(:response) { instance_double(Net::HTTPOK) }
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
    let(:integration_collection_mapping) do
      create(
        :netsuite_collection_mapping,
        integration: integration_customer.integration,
        mapping_type: :fallback_item,
        settings: {external_id: "1", external_account_code: "11", external_name: ""}
      )
    end
    let(:body) do
      p = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
      File.read(p)
    end

    before do
      integration_collection_mapping

      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:post_with_response).and_return(response)
      allow(response).to receive(:body).and_return(body)
    end

    it "does not throw an error when it is a tax error" do
      expect { described_class.perform_now(organization: invoice.organization, invoice_ids: [invoice.id]) }
        .not_to raise_error
    end
  end
end
