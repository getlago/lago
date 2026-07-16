# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::DunningCampaigns::FinishedService do
  subject(:webhook_service) { described_class.new(object: customer, options: webhook_options) }

  let(:customer) { create(:customer) }
  let(:webhook_options) { {dunning_campaign_code: "campaign_code"} }

  it_behaves_like "creates webhook", "dunning_campaign.finished", "dunning_campaign"
end
