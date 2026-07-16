# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationMappings::UpdateService do
  let(:integration_mapping) { create(:netsuite_mapping, integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  describe "#call" do
    subject(:service_call) { described_class.call(integration_mapping:, params: update_args) }

    before { integration_mapping }

    let(:update_args) do
      {
        external_id: "456",
        external_name: "Name1",
        external_account_code: "code-2"
      }
    end

    context "without validation errors" do
      it "updates an integration mapping" do
        service_call

        integration_mapping = IntegrationMappings::NetsuiteMapping.order(:updated_at).last

        expect(integration_mapping.external_id).to eq("456")
        expect(integration_mapping.external_name).to eq("Name1")
        expect(integration_mapping.external_account_code).to eq("code-2")
      end

      it "returns an integration mapping in result object" do
        result = service_call

        expect(result.integration_mapping).to be_a(IntegrationMappings::NetsuiteMapping)
      end
    end
  end
end
