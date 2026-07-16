# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::CreateJob do
  let(:payment) { create(:payment) }

  it "calls the create service" do
    allow(PaymentReceipts::CreateService)
      .to receive(:call!).with(payment:).and_return(BaseService::Result.new)

    described_class.perform_now(payment)

    expect(PaymentReceipts::CreateService).to have_received(:call!)
  end
end
