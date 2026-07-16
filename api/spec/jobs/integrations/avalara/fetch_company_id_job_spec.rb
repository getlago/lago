# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Avalara::FetchCompanyIdJob do
  describe "#perform" do
    subject(:job) { described_class }

    let(:service) { instance_double(Integrations::Avalara::FetchCompanyIdService) }
    let(:integration) { create(:avalara_integration) }
    let(:result) { BaseService::Result.new }

    before do
      allow(Integrations::Avalara::FetchCompanyIdService).to receive(:call).and_return(result)
    end

    it "calls dedicated service" do
      described_class.perform_now(integration:)

      expect(Integrations::Avalara::FetchCompanyIdService).to have_received(:call)
    end
  end
end
