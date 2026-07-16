# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizeJob do
  let(:invoice) { create(:invoice) }

  let(:result) { BaseService::Result.new }

  it "delegates to the RefreshDraftAndFinalizeService service" do
    allow(Invoices::RefreshDraftAndFinalizeService).to receive(:call)
      .with(invoice:)
      .and_return(result)

    described_class.perform_now(invoice)

    expect(Invoices::RefreshDraftAndFinalizeService).to have_received(:call)
  end

  context "when there was a tax fetching error in RefreshDraftAndFinalize service" do
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
      expect { described_class.perform_now(invoice) }.not_to raise_error
    end
  end

  describe "retry_on" do
    [
      [Customers::FailedToAcquireLock.new("customer-1-prepaid_credit"), 25],
      [ActiveRecord::StaleObjectError.new("Attempted to update a stale object: Wallet."), 25],
      [Sequenced::SequenceError.new("Sequenced::SequenceError"), 15]
    ].each do |error, attempts|
      error_class = error.class

      context "when a #{error_class} error is raised" do
        before do
          allow(Invoices::RefreshDraftAndFinalizeService).to receive(:call).and_raise(error)
        end

        it "raises a #{error_class.name} error and retries" do
          assert_performed_jobs(attempts, only: [described_class]) do
            expect do
              described_class.perform_later(invoice)
            end.to raise_error(error_class)
          end
        end
      end
    end
  end
end
