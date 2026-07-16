# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::OrganizationBillingJob do
  subject { described_class }

  describe ".perform" do
    let(:organization) { create(:organization, api_keys: []) }
    let(:result) { BaseService::Result.new }

    it "calls the subscriptions biller service" do
      allow(Subscriptions::OrganizationBillingService).to receive(:call!)
        .with(organization:)
        .and_return(result)

      described_class.perform_now(organization:)

      expect(Subscriptions::OrganizationBillingService).to have_received(:call!)
    end
  end
end
