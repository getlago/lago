# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Hubspot::Subscriptions::DeployObjectJob do
  describe "#perform" do
    subject(:deploy_object_job) { described_class }

    let(:integration) { create(:hubspot_integration) }
    let(:result) { BaseService::Result.new }

    before do
      allow(Integrations::Hubspot::Subscriptions::DeployObjectService).to receive(:call).and_return(result)
    end

    it "calls the DeployObjectService to deploy subscription custom object" do
      deploy_object_job.perform_now(integration:)

      expect(Integrations::Hubspot::Subscriptions::DeployObjectService).to have_received(:call)
    end
  end
end
