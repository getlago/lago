# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Hubspot::CreateJob do
  subject(:create_job) { described_class }

  let(:subscription) { create(:subscription) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Subscriptions::Hubspot::CreateService).to receive(:call).and_return(result)
  end

  context "when the service call is not successful" do
    before do
      allow(result).to receive(:success?).and_return(false)
      allow(result).to receive(:raise_if_error!).and_raise(StandardError)
    end

    it "raises an error" do
      expect { create_job.perform_now(subscription:) }.to raise_error(StandardError)
    end
  end

  context "when the service call is successful" do
    it "calls the aggregator create subscription hubspot service" do
      described_class.perform_now(subscription:)

      expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateService).to have_received(:call)
    end

    it "enqueues the aggregator create customer association subscription job" do
      expect do
        described_class.perform_now(subscription:)
      end.to have_enqueued_job(Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationJob).with(subscription:)
    end
  end
end
