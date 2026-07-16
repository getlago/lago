# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCollectionMappings::DestroyService do
  subject(:destroy_service) { described_class.new(integration_collection_mapping:) }

  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  describe ".call" do
    before { integration_collection_mapping }

    context "when integration is present" do
      let(:integration_collection_mapping) { create(:netsuite_collection_mapping, integration:) }

      it "destroys the integration mapping" do
        expect { destroy_service.call }
          .to change(IntegrationCollectionMappings::BaseCollectionMapping, :count).by(-1)
      end
    end

    context "when integration is not found" do
      let(:integration_collection_mapping) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("integration_collection_mapping_not_found")
      end
    end
  end
end
