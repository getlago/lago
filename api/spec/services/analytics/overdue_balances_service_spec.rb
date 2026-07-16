# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::OverdueBalancesService do
  let(:service) { described_class.new(organization) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }

  describe "#call" do
    subject(:service_call) { service.call }

    it "returns success" do
      expect(service_call).to be_success
    end

    it "calls Analytics::OverdueBalance" do
      allow(Analytics::OverdueBalance).to receive(:find_all_by)
      service_call
      expect(Analytics::OverdueBalance).to have_received(:find_all_by).with(organization.id)
    end
  end
end
