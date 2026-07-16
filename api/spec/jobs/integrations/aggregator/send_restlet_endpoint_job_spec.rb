# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::SendRestletEndpointJob do
  subject(:send_endpoint_job) { described_class }

  let(:integration) { create(:netsuite_integration) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::SendRestletEndpointService).to receive(:call).and_return(result)
  end

  it "sends restlet url to the aggregator" do
    described_class.perform_now(integration:)

    expect(Integrations::Aggregator::SendRestletEndpointService).to have_received(:call)
  end
end
