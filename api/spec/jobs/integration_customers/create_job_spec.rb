# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::CreateJob do
  let(:integration) { create(:netsuite_integration) }
  let(:customer) { create(:customer) }
  let(:integration_customer_params) do
    {
      sync_with_provider: true
    }
  end

  describe "#perform" do
    subject(:create_job) { described_class }

    before do
      allow(IntegrationCustomers::CreateService).to receive(:call!)
    end

    it "calls the create service" do
      described_class.perform_now(integration_customer_params:, integration:, customer:)

      expect(IntegrationCustomers::CreateService).to have_received(:call!)
    end
  end

  describe "#lock_key_arguments" do
    it "returns customer and integration for the lock key" do
      job = described_class.new(
        integration_customer_params: integration_customer_params,
        integration: integration,
        customer: customer
      )

      expect(job.lock_key_arguments).to eq([integration, customer])
    end
  end
end
