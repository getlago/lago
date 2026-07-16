# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::RefreshDraftJob do
  let(:invoice) { create(:invoice, ready_to_be_refreshed: true) }
  let(:result) { BaseService::Result.new }

  it "delegates to the RefreshDraft service" do
    allow(Invoices::RefreshDraftService).to receive(:call).with(invoice:).and_return(result)

    described_class.perform_now(invoice:)

    expect(Invoices::RefreshDraftService).to have_received(:call)
  end

  it "does not delegate to the RefreshDraft service if the ready_to_be_refreshed? is false" do
    allow(Invoices::RefreshDraftService).to receive(:call).with(invoice:)

    invoice.update ready_to_be_refreshed: false
    described_class.perform_now(invoice:)

    expect(Invoices::RefreshDraftService).not_to have_received(:call)
  end

  it "has a lock_ttl of 12.hours" do
    # When there's lots of draft invoices to be refreshed, we might end up enqueueing multiple of them.
    # This will block all queues with lower prio than the `invoices` queue. (e.g. wallets). This is undesirable,
    # so we bump the lock_ttl for this job to 6 hours
    expect(described_class.new.lock_options[:lock_ttl]).to eq(12.hours)
  end

  context "when there was a tax fetching error in RefreshDraft service" do
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
      expect { described_class.perform_now(invoice:) }.not_to raise_error
    end
  end
end
