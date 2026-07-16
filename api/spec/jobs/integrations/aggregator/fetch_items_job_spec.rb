# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::FetchItemsJob do
  subject(:fetch_items_job) { described_class }

  let(:integration) { create(:netsuite_integration) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::ItemsService).to receive(:call).and_return(result)
  end

  it "calls the items service" do
    described_class.perform_now(integration:)

    expect(Integrations::Aggregator::ItemsService).to have_received(:call)
  end
end
