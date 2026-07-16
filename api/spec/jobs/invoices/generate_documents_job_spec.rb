# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::GenerateDocumentsJob do
  subject { described_class.perform_now(invoice:, notify:) }

  let(:invoice) { create(:invoice) }
  let(:result) { BaseService::Result.new }
  let(:notify) { false }

  before do
    allow(Invoices::GeneratePdfService).to receive(:call).with(invoice:).and_return(result)
    allow(Invoices::GenerateXmlService).to receive(:call).with(invoice:).and_return(result)
  end

  it_behaves_like "a configurable queue", "pdfs", "SIDEKIQ_PDFS", "invoices" do
    let(:arguments) { {invoice:, notify:} }
  end

  it_behaves_like "a retryable on network errors job" do
    let(:service_class) { Invoices::GenerateXmlService }
    let(:job_arguments) { {invoice:, notify:} }
  end

  it "generates the PDF" do
    subject
    expect(Invoices::GeneratePdfService).to have_received(:call)
  end

  it "generates the XML" do
    subject
    expect(Invoices::GenerateXmlService).to have_received(:call)
  end

  context "when notify is sent" do
    context "with true" do
      let(:notify) { true }

      it "enqueues Invoices::NotifyJob" do
        expect { subject }.to have_enqueued_job(Invoices::NotifyJob).with(invoice:)
      end
    end

    context "with false" do
      let(:notify) { false }

      it "does nothing" do
        expect { subject }.not_to have_enqueued_job(Invoices::NotifyJob)
      end
    end
  end
end
