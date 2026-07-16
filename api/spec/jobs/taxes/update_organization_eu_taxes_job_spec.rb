# frozen_string_literal: true

require "rails_helper"

RSpec.describe Taxes::UpdateOrganizationEuTaxesJob do
  let(:organization) { create(:organization) }

  describe ".perform" do
    let(:organization) { create(:organization, api_keys: []) }
    let(:result) { BaseService::Result.new }

    it "calls the subscriptions biller service" do
      allow(Taxes::AutoGenerateService).to receive(:call!).and_call_original

      described_class.perform_now(organization)

      expect(Taxes::AutoGenerateService).to have_received(:call!).with(organization:)
    end
  end
end
