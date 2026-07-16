# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::HandleEventJob do
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }

  let(:stripe_event) do
    {}
  end

  before do
    allow(PaymentProviders::Stripe::HandleEventService)
      .to receive(:call)
      .and_return(result)
  end

  it "calls the handle event service" do
    described_class.perform_now(
      organization:,
      event: stripe_event
    )

    expect(PaymentProviders::Stripe::HandleEventService).to have_received(:call)
  end
end
