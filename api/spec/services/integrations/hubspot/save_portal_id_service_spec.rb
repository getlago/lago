# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Hubspot::SavePortalIdService do
  describe "#call" do
    let(:portal_id) { "123456" }
    let(:integration) { create(:hubspot_integration) }
    let(:service_call) { described_class.call(integration:) }
    let(:result) { BaseService::Result.new }
    let(:account_information) { OpenStruct.new(id: portal_id) }

    before do
      result.account_information = account_information
      allow(Integrations::Aggregator::AccountInformationService).to receive(:call).and_return(result)
    end

    context "when the service is successful" do
      it "saves the portal ID to the integration" do
        expect { service_call }.to change { integration.reload.portal_id }.to(portal_id)
      end

      it "returns a success result" do
        result = service_call
        expect(result).to be_success
      end
    end

    context "when the service fails" do
      before do
        allow(integration).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(integration))
      end

      it "does not change the portal ID" do
        expect { service_call }.not_to change { integration.reload.portal_id }
      end

      it "returns an error message" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
      end
    end
  end
end
