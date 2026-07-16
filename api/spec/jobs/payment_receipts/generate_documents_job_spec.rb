# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::GenerateDocumentsJob do
  subject { described_class.perform_now(payment_receipt:, notify:) }

  let(:payment_receipt) { create(:payment_receipt) }
  let(:result) { BaseService::Result.new }
  let(:notify) { false }

  before do
    allow(PaymentReceipts::GeneratePdfService).to receive(:call).with(payment_receipt:).and_return(result)
    allow(PaymentReceipts::GenerateXmlService).to receive(:call).with(payment_receipt:).and_return(result)
  end

  it_behaves_like "a configurable queue", "pdfs", "SIDEKIQ_PDFS", "low_priority" do
    let(:arguments) { {payment_receipt:, notify:} }
  end

  it_behaves_like "a retryable on network errors job" do
    let(:service_class) { PaymentReceipts::GenerateXmlService }
    let(:job_arguments) { {payment_receipt:, notify:} }
  end

  it "generates the PDF" do
    subject
    expect(PaymentReceipts::GeneratePdfService).to have_received(:call)
  end

  it "generates the XML" do
    subject
    expect(PaymentReceipts::GenerateXmlService).to have_received(:call)
  end

  context "when notify is sent" do
    context "with true" do
      let(:notify) { true }

      it "enqueues PaymentReceipts::NotifyJob" do
        expect { subject }.to have_enqueued_job(PaymentReceipts::NotifyJob).with(payment_receipt:)
      end
    end

    context "with false" do
      let(:notify) { false }

      it "does nothing" do
        expect { subject }.not_to have_enqueued_job(PaymentReceipts::NotifyJob)
      end
    end
  end
end
