# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Avalara::FetchCompanyIdService do
  describe "#call" do
    let(:service_call) { described_class.call(integration:) }
    let(:company_id) { "abc-12345" }
    let(:integration) { create(:avalara_integration, company_id: nil) }
    let(:result) { BaseService::Result.new }
    let(:company) do
      {
        "id" => company_id
      }
    end

    before do
      result.company = company
      allow(Integrations::Aggregator::Taxes::Avalara::FetchCompanyIdService).to receive(:call).and_return(result)
    end

    context "when the service response is successful" do
      it "saves the company id to the integration" do
        expect { service_call }.to change { integration.reload.company_id }.to(company_id)
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

      it "does not change the company id" do
        expect { service_call }.not_to change { integration.reload.company_id }
      end

      it "returns an error message" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
      end
    end
  end
end
