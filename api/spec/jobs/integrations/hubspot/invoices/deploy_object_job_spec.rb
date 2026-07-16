# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Hubspot::Invoices::DeployObjectJob do
  describe "#perform" do
    subject(:deploy_object_job) { described_class }

    let(:integration) { create(:hubspot_integration) }
    let(:result) { BaseService::Result.new }

    before do
      allow(Integrations::Hubspot::Invoices::DeployObjectService).to receive(:call).and_return(result)
    end

    it "calls the DeployObjectService to deploy invoice custom object" do
      deploy_object_job.perform_now(integration:)

      expect(Integrations::Hubspot::Invoices::DeployObjectService).to have_received(:call)
    end
  end
end
