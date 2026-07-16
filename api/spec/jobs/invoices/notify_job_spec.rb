# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::NotifyJob do
  subject { described_class.perform_now(invoice:) }

  let(:invoice) { create(:invoice) }

  it "sends email" do
    expect { subject }.to have_enqueued_mail(InvoiceMailer, :created)
      .with(params: {invoice:}, args: [])
  end
end
