# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::StripeCreateJob do
  let(:stripe_customer) { create(:stripe_customer) }

  let(:stripe_service) { instance_double(PaymentProviderCustomers::StripeService) }

  it "calls the stripe create service" do
    allow(PaymentProviderCustomers::StripeService).to receive(:new)
      .with(stripe_customer)
      .and_return(stripe_service)
    allow(stripe_service).to receive(:create)
      .and_return(BaseService::Result.new)

    described_class.perform_now(stripe_customer)

    expect(PaymentProviderCustomers::StripeService).to have_received(:new)
    expect(stripe_service).to have_received(:create)
  end
end
