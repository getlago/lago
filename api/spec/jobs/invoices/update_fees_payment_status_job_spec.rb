# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::UpdateFeesPaymentStatusJob do
  let(:invoice) { create(:invoice, payment_status: :succeeded) }
  let(:fee) { create(:fee, invoice:) }

  before { fee }

  it "updates the payment_status of the fee" do
    described_class.perform_now(invoice)

    expect(fee.reload.payment_status).to eq("succeeded")
  end
end
