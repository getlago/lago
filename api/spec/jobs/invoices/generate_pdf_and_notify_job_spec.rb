# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::GeneratePdfAndNotifyJob do
  subject { described_class.perform_now(invoice:, email:) }

  let(:invoice) { create(:invoice) }
  let(:email) { true }
  let(:notify) { email }

  it "enqueues GenerateDocumentsJob" do
    expect { subject }.to enqueue_job(Invoices::GenerateDocumentsJob).with(invoice:, notify:)
  end
end
