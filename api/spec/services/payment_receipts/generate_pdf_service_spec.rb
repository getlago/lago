# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::GeneratePdfService do
  subject(:payment_receipt_generate_service) { described_class.new(payment_receipt:, context:) }

  let(:context) { "graphql" }
  let(:organization) { create(:organization, name: "LAGO") }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:) }
  let(:invoice) { create(:invoice, customer:, status: :finalized, organization:) }
  let(:payment) { create(:payment, payable: invoice) }
  let(:payment_receipt) { create(:payment_receipt, payment:, organization:) }
  let(:blank_pdf_path) { Rails.root.join("spec/fixtures/blank.pdf") }

  before do
    billing_entity = organization.default_billing_entity
    billing_entity.logo.attach(
      io: File.open(Rails.root.join("spec/factories/images/logo.png")),
      content_type: "image/png",
      filename: "logo"
    )
    stub_pdf_generation
  end

  describe "#call" do
    it "generates the payment receipt synchronously" do
      result = payment_receipt_generate_service.call

      expect(result.payment_receipt.file).to be_present
    end

    it "calls the SendWebhook job" do
      expect { payment_receipt_generate_service.call }.to have_enqueued_job(SendWebhookJob)
    end

    it "produces an activity log" do
      receipt = described_class.call(payment_receipt:, context:).payment_receipt

      expect(Utils::ActivityLog).to have_produced("payment_receipt.generated").with(receipt)
    end

    context "with not found payment receipt" do
      let(:payment_receipt) { nil }

      it "returns a result with error" do
        result = payment_receipt_generate_service.call

        expect(result.success).to be_falsey
        expect(result.error.error_code).to eq("payment_receipt_not_found")
      end
    end

    context "when related to a progressive billing invoice" do
      let(:invoice) do
        create(:invoice, :progressive_billing_invoice, customer:, status: :finalized, organization:)
      end

      it "successfully generates the payment receipt" do
        result = payment_receipt_generate_service.call

        expect(result.payment_receipt.file).to be_present
      end
    end

    context "with already generated file" do
      before do
        payment_receipt.file.attach(
          io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
          filename: "receipt.pdf",
          content_type: "application/pdf"
        )
      end

      it "does not generate the pdf" do
        allow(LagoHttpClient::Client).to receive(:new)

        payment_receipt_generate_service.call

        expect(LagoHttpClient::Client).not_to have_received(:new)
      end

      it "does not call the SendWebhook job" do
        expect { payment_receipt_generate_service.call }.not_to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when in API context" do
      let(:context) { "api" }

      it "calls the SendWebhook job" do
        expect { payment_receipt_generate_service.call }.to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when in Admin context" do
      let(:context) { "admin" }

      before do
        payment_receipt.file.attach(
          io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
          filename: "receipt.pdf",
          content_type: "application/pdf"
        )
      end

      it "generates the invoice synchronously" do
        result = payment_receipt_generate_service.call

        expect(result.payment_receipt.file.filename.to_s).not_to eq("receipt.pdf")
      end
    end

    context "when create temp files" do
      let(:pdf_tempfile) { instance_double(Tempfile).as_null_object }

      before do
        allow(pdf_tempfile).to receive(:path).and_return(blank_pdf_path)
        allow(Tempfile).to receive(:new).and_call_original
        allow(Tempfile).to receive(:new).with([payment_receipt.number, ".pdf"]).and_return(pdf_tempfile)
      end

      it "unlink the pdf file at the end" do
        described_class.call(payment_receipt:, context:)

        expect(pdf_tempfile).to have_received(:unlink)
      end

      context "with einvoicing enabled" do
        let(:xml_tempfile) { instance_double(Tempfile).as_null_object }

        before do
          payment_receipt.billing_entity.update(country: "FR", einvoicing: true)

          allow(Tempfile).to receive(:new).with([payment_receipt.number, ".xml"]).and_return(xml_tempfile)
          allow(Utils::PdfAttachmentService).to receive(:call)
        end

        it "unlink all files at the end" do
          described_class.call(payment_receipt:, context:)

          expect(pdf_tempfile).to have_received(:unlink)
          expect(xml_tempfile).to have_received(:unlink)
        end
      end
    end

    context "when einvoicing is enabled" do
      let(:fake_xml) { "<xml>content</xml>" }
      let(:country) { nil }
      let(:create_xml_result) { BaseService::Result.new.tap { |result| result.xml = fake_xml } }

      before do
        payment_receipt.billing_entity.update(country:, einvoicing: true)

        allow(EInvoices::Payments::Cii::CreateService).to receive(:call).and_return(create_xml_result)
        allow(Utils::PdfAttachmentService).to receive(:call)
      end

      context "with FR country" do
        let(:country) { "FR" }

        it "generates the payment_receipt with attached cii xml synchronously" do
          result = described_class.call(payment_receipt:, context:)

          expect(Utils::PdfAttachmentService).to have_received(:call)
          expect(EInvoices::Payments::Cii::CreateService).to have_received(:call)
          expect(result.payment_receipt.file).to be_present
        end
      end
    end
  end
end
