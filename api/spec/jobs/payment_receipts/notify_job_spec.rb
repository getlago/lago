# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::NotifyJob do
  let(:payment_receipt) { create(:payment_receipt) }

  it "sends the email" do
    expect { described_class.perform_now(payment_receipt:) }
      .to have_enqueued_mail(PaymentReceiptMailer, :created).with(params: {payment_receipt:}, args: [])
  end
end
