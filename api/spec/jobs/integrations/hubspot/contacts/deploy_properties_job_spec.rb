# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Hubspot::Contacts::DeployPropertiesJob do
  describe "#perform" do
    subject(:deploy_properties_job) { described_class }

    let(:integration) { create(:hubspot_integration) }
    let(:result) { BaseService::Result.new }

    before do
      allow(Integrations::Hubspot::Contacts::DeployPropertiesService).to receive(:call).and_return(result)
    end

    it "calls the DeployPropertiesService to sync contacts custom properties" do
      deploy_properties_job.perform_now(integration:)

      expect(Integrations::Hubspot::Contacts::DeployPropertiesService).to have_received(:call)
    end
  end
end
