# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Hubspot::CreateJob do
  subject(:create_job) { described_class }

  let(:invoice) { create(:invoice) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Invoices::Hubspot::CreateService).to receive(:call).and_return(result)
  end

  context "when the service call is not successful" do
    before do
      allow(result).to receive(:success?).and_return(false)
      allow(result).to receive(:raise_if_error!).and_raise(StandardError)
    end

    it "raises an error" do
      expect { create_job.perform_now(invoice:) }.to raise_error(StandardError)
    end
  end

  context "when the service call is successful" do
    it "calls the aggregator create invoice hubspot service" do
      described_class.perform_now(invoice:)

      expect(Integrations::Aggregator::Invoices::Hubspot::CreateService).to have_received(:call)
    end

    it "enqueues the aggregator create customer association invoice job" do
      expect do
        described_class.perform_now(invoice:)
      end.to have_enqueued_job(Integrations::Aggregator::Invoices::Hubspot::CreateCustomerAssociationJob).with(invoice:)
    end
  end
end
