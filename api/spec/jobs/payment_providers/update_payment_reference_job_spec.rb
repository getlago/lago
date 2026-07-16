# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::UpdatePaymentReferenceJob do
  subject(:perform_job) { described_class.perform_now(payment) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment) { create(:payment, payable: invoice, organization:, customer:) }

  before do
    allow(PaymentProviders::UpdatePaymentReferenceService).to receive(:call!)
  end

  it "delegates to UpdatePaymentReferenceService with the payment" do
    perform_job

    expect(PaymentProviders::UpdatePaymentReferenceService).to have_received(:call!).with(payment:)
  end
end
