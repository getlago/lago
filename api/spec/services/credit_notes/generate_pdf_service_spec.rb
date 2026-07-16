# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::GeneratePdfService do
  subject(:credit_note_generate_service) { described_class.new(credit_note:, context:) }

  let(:organization) { create(:organization, name: "LAGO") }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:credit_note) { create(:credit_note, invoice:, customer:) }
  let(:fee) { create(:fee, invoice:) }
  let(:credit_note_item) { create(:credit_note_item, credit_note:, fee:) }
  let(:context) { nil }

  before do
    credit_note_item

    stub_pdf_generation
    allow(Utils::PdfGenerator).to receive(:call).and_call_original
  end

  describe ".call" do
    it "generates the credit note synchronously" do
      result = credit_note_generate_service.call

      expect(result.credit_note.file).to be_present
    end

    it "uses credit_note template" do
      credit_note_generate_service.call

      expect(Utils::PdfGenerator).to have_received(:call).with(template: "credit_notes/credit_note", context: credit_note)
    end

    it "produces an activity log" do
      result = credit_note_generate_service.call

      expect(Utils::ActivityLog).to have_produced("credit_note.generated").with(result.credit_note)
    end

    context "when credit note is for self billed invoice" do
      let(:invoice) { create(:invoice, :self_billed, customer:, organization:) }
      let(:credit_note) { create(:credit_note, invoice:, customer:) }

      it "uses self billed template" do
        credit_note_generate_service.call

        expect(Utils::PdfGenerator).to have_received(:call).with(template: "credit_notes/self_billed", context: credit_note)
      end
    end

    context "with preferred locale" do
      before do
        customer.update!(document_locale: "fr")

        allow(I18n).to receive(:with_locale).and_yield
      end

      it "sets the correct document locale" do
        credit_note_generate_service.call
        expect(I18n).to have_received(:with_locale).with(:fr)
      end
    end

    context "when using temp files" do
      let(:pdf_tempfile) { instance_double(Tempfile).as_null_object }
      let(:blank_pdf_path) { Rails.root.join("spec/fixtures/blank.pdf") }

      before do
        allow(pdf_tempfile).to receive(:path).and_return(blank_pdf_path)
        allow(Tempfile).to receive(:new).and_call_original
        allow(Tempfile).to receive(:new).with([credit_note.number, ".pdf"]).and_return(pdf_tempfile)
      end

      it "unlink the pdf file at the end" do
        described_class.call(credit_note:, context:)

        expect(pdf_tempfile).to have_received(:unlink)
      end

      context "with einvoicing enabled" do
        let(:xml_tempfile) { instance_double(Tempfile).as_null_object }

        before do
          invoice.billing_entity.update(country: "FR", einvoicing: true)

          allow(Tempfile).to receive(:new).with([credit_note.number, ".xml"]).and_return(xml_tempfile)
          allow(Utils::PdfAttachmentService).to receive(:call)
        end

        it "unlink all files at the end" do
          described_class.call(credit_note:, context:)

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
        credit_note.billing_entity.update(country:, einvoicing: true)

        allow(EInvoices::CreditNotes::Cii::CreateService).to receive(:call).and_return(create_xml_result)
        allow(Utils::PdfAttachmentService).to receive(:call)
      end

      context "with FR country" do
        let(:country) { "FR" }

        it "generates the invoice with attached cii xml synchronously" do
          result = described_class.call(credit_note:, context:)

          expect(EInvoices::CreditNotes::Cii::CreateService).to have_received(:call)
          expect(Utils::PdfAttachmentService).to have_received(:call)
          expect(result.credit_note.file).to be_present
        end
      end
    end

    context "with not found credit_note" do
      let(:credit_note) { nil }
      let(:credit_note_item) { nil }

      it "returns a result with error" do
        result = credit_note_generate_service.call

        expect(result.success).to be_falsey
        expect(result.error.error_code).to eq("credit_note_not_found")
      end
    end

    context "when credit_note is draft" do
      let(:credit_note) { create(:credit_note, :draft, invoice:, customer:) }

      it "returns a not found error" do
        result = credit_note_generate_service.call

        expect(result.success).to be_falsey
        expect(result.error.error_code).to eq("credit_note_not_found")
      end
    end

    context "with already generated file" do
      before do
        credit_note.file.attach(
          io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
          filename: "credit_note.pdf",
          content_type: "application/pdf"
        )
      end

      it "does not generate the pdf" do
        allow(LagoHttpClient::Client).to receive(:new)

        credit_note_generate_service.call

        expect(LagoHttpClient::Client).not_to have_received(:new)
      end
    end

    context "when context is API" do
      let(:context) { "api" }

      it "calls the SendWebhook job" do
        expect do
          credit_note_generate_service.call
        end.to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when context is admin" do
      let(:context) { "admin" }

      it "calls the SendWebhook job" do
        expect do
          credit_note_generate_service.call
        end.to have_enqueued_job(SendWebhookJob)
      end
    end
  end
end
