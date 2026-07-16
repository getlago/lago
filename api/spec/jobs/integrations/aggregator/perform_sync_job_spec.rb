# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::PerformSyncJob do
  subject(:perform_sync_job) { described_class.perform_now(integration:, sync_items:) }

  let(:integration) { create(:netsuite_integration) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::SyncService).to receive(:call).and_return(result)
    allow(Integrations::Aggregator::ItemsService).to receive(:call).and_return(result)

    perform_sync_job
  end

  context "when sync_items is true" do
    let(:sync_items) { true }

    it "calls the aggregator sync service" do
      expect(Integrations::Aggregator::SyncService).to have_received(:call)
    end

    it "calls the aggregator items service" do
      expect(Integrations::Aggregator::ItemsService).to have_received(:call)
    end
  end

  context "when sync_items is false" do
    let(:sync_items) { false }

    it "calls the aggregator sync service" do
      expect(Integrations::Aggregator::SyncService).to have_received(:call)
    end

    it "does not call the aggregator items service" do
      expect(Integrations::Aggregator::ItemsService).not_to have_received(:call)
    end
  end
end
