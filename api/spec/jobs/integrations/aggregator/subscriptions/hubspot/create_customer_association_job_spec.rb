# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationJob do
  subject(:create_job) { described_class }

  let(:subscription) { create(:subscription) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationService)
      .to receive(:call).and_return(result)
  end

  it "calls the aggregator create subscription hubspot service" do
    described_class.perform_now(subscription:)

    expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationService).to have_received(:call)
  end
end
