# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaigns::ProcessAttemptJob do
  let(:result) { BaseService::Result.new }
  let(:customer) { build :customer }
  let(:dunning_campaign_threshold) { build :dunning_campaign_threshold }
  let(:billing_entity) { build :billing_entity }

  before do
    allow(DunningCampaigns::ProcessAttemptService)
      .to receive(:call)
      .and_return(result)
  end

  it "calls DunningCampaigns::ProcessAttemptService" do
    described_class.perform_now(customer:, dunning_campaign_threshold:, billing_entity:)

    expect(DunningCampaigns::ProcessAttemptService)
      .to have_received(:call)
      .with(customer:, dunning_campaign_threshold:, billing_entity:)
  end
end
