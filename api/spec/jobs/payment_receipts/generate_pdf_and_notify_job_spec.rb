# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::GeneratePdfAndNotifyJob do
  subject { described_class.perform_now(payment_receipt:, email:) }

  let(:payment_receipt) { create(:payment_receipt) }
  let(:email) { true }
  let(:notify) { email }

  it "enqueues GenerateDocumentsJob" do
    expect { subject }.to enqueue_job(PaymentReceipts::GenerateDocumentsJob).with(payment_receipt:, notify:)
  end
end
