# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Payments::CreateJob do
  subject(:create_job) { described_class }

  let(:payment) { create(:payment) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Payments::CreateService).to receive(:call).and_return(result)
  end

  it "calls the aggregator create payment service" do
    described_class.perform_now(payment:)

    expect(Integrations::Aggregator::Payments::CreateService).to have_received(:call)
  end
end
