# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Organizations::UpdateService do
  subject(:update_service) { described_class.new(organization:, params:) }

  let(:organization) { create(:organization) }

  let(:params) do
    {
      name: "FooBar",
      premium_integrations: ["okta"]
    }
  end

  describe "#call" do
    it "updates the organization" do
      result = update_service.call

      expect(result.organization.name).to eq("FooBar")
      expect(result.organization.premium_integrations).to include("okta")

      organization.reload

      expect(organization.reload.name).to eq("FooBar")
      expect(organization.premium_integrations).to include("okta")
    end

    context "when organization is nil" do
      let(:organization) { nil }

      it "returns a not found error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
      end
    end
  end
end
