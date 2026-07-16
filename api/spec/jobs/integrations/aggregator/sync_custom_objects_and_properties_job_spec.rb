# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::SyncCustomObjectsAndPropertiesJob do
  describe "#perform" do
    subject(:sync_job) { described_class }

    let(:integration) { create(:hubspot_integration) }

    before do
      allow(Integrations::Hubspot::Subscriptions::DeployObjectService).to receive(:call)
      allow(Integrations::Hubspot::Invoices::DeployObjectService).to receive(:call)
      allow(Integrations::Hubspot::Companies::DeployPropertiesService).to receive(:call)
      allow(Integrations::Hubspot::Contacts::DeployPropertiesService).to receive(:call)
    end

    it "call all the services with the current integration" do
      sync_job.perform_now(integration: integration)

      expect(Integrations::Hubspot::Subscriptions::DeployObjectService).to have_received(:call).with(integration:)
      expect(Integrations::Hubspot::Invoices::DeployObjectService).to have_received(:call).with(integration:)
      expect(Integrations::Hubspot::Companies::DeployPropertiesService).to have_received(:call).with(integration:)
      expect(Integrations::Hubspot::Contacts::DeployPropertiesService).to have_received(:call).with(integration:)
    end
  end
end
