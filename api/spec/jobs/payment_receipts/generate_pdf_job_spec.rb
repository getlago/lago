# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::GeneratePdfJob do
  let(:payment_receipt) { create(:payment_receipt) }
  let(:result) { BaseService::Result.new }

  it "delegates to the Generate service" do
    allow(PaymentReceipts::GeneratePdfService).to receive(:call)
      .with(payment_receipt:, context: "api")
      .and_return(result)

    described_class.perform_now(payment_receipt)

    expect(PaymentReceipts::GeneratePdfService).to have_received(:call)
  end
end
