# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Cashfree::HandleEventJob do
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }

  let(:cashfree_event) do
    {}
  end

  before do
    allow(PaymentProviders::Cashfree::HandleEventService)
      .to receive(:call)
      .and_return(result)
  end

  it "calls the handle event service" do
    described_class.perform_now(
      organization:,
      event: cashfree_event
    )

    expect(PaymentProviders::Cashfree::HandleEventService).to have_received(:call)
  end
end
