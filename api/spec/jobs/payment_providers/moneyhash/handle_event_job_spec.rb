# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::HandleEventJob do
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }

  let(:moneyhash_event) { {} }

  before do
    allow(PaymentProviders::Moneyhash::HandleEventService)
      .to receive(:call)
      .and_return(result)
  end

  it "calls the handle event service" do
    described_class.perform_now(organization:, event_json: moneyhash_event)

    expect(PaymentProviders::Moneyhash::HandleEventService).to have_received(:call)
  end
end
