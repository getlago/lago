# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::StripeSyncFundingInstructionsJob do
  subject(:stripe_sync_funding_instructions_job) { described_class }

  let(:stripe_customer) { create(:stripe_customer) }
  let(:stripe_service) { instance_double(PaymentProviderCustomers::Stripe::SyncFundingInstructionsService) }

  it "calls the funding instructions sync service" do
    allow(PaymentProviderCustomers::Stripe::SyncFundingInstructionsService).to receive(:new)
      .with(stripe_customer)
      .and_return(stripe_service)
    allow(stripe_service).to receive(:call)
      .and_return(BaseService::Result.new)

    stripe_sync_funding_instructions_job.perform_now(stripe_customer)

    expect(PaymentProviderCustomers::Stripe::SyncFundingInstructionsService).to have_received(:new)
    expect(stripe_service).to have_received(:call)
  end
end
