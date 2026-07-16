# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceMailer do
  subject(:invoice_mailer) { described_class }

  let(:invoice) { create(:invoice, organization:, billing_entity:, fees_amount_cents: 100) }
  let(:organization) { create(:organization) }
  let(:billing_entity) do
    create(
      :billing_entity,
      organization:,
      name: "ACME Corp",
      email: billing_entity_email
    )
  end
  let(:billing_entity_email) { "billing_entity@email.com" }

  before do
    invoice.file.attach(io: File.open(Rails.root.join("spec/fixtures/blank.pdf")), filename: "blank.pdf")
  end

  describe "#created" do
    specify do
      mailer = invoice_mailer.with(invoice:).created

      expect(mailer.subject).to eq("Your Invoice from ACME Corp ##{invoice.number}")
      expect(mailer.to).to eq([invoice.customer.email])
      expect(mailer.from).to eq(["noreply@getlago.com"])
      expect(mailer.reply_to).to eq([billing_entity_email])
      expect(mailer.attachments).not_to be_empty
      expect(mailer.attachments.first.filename).to eq("invoice-#{invoice.number}.pdf")
    end

    context "when pdfs are disabled" do
      before { ENV["LAGO_DISABLE_PDF_GENERATION"] = "true" }

      it "does not attach the pdf" do
        mailer = invoice_mailer.with(invoice:).created

        expect(mailer.attachments).to be_empty
      end
    end

    context "with no pdf file" do
      let(:pdf_service) { instance_double(Invoices::GeneratePdfService) }

      before do
        invoice.file = nil

        allow(Invoices::GeneratePdfService).to receive(:new)
          .and_return(pdf_service)
        allow(pdf_service).to receive(:call)
      end

      it "calls the invoice pdf generate service" do
        mailer = invoice_mailer.with(invoice:).created

        expect(mailer.to).not_to be_nil
        expect(Invoices::GeneratePdfService).to have_received(:new)
      end
    end

    context "when billing_entity email is nil" do
      let(:billing_entity_email) { nil }

      it "returns a mailer with nil values" do
        mailer = invoice_mailer.with(invoice:).created

        expect(mailer.to).to be_nil
      end
    end

    context "when customer email is nil" do
      before do
        invoice.customer.update(email: nil)
      end

      it "returns a mailer with nil values" do
        mailer = invoice_mailer.with(invoice:).created

        expect(mailer.to).to be_nil
      end
    end

    context "when customer email is an empty string" do
      before do
        invoice.customer.update(email: "")
      end

      it "returns a mailer with nil values" do
        mailer = invoice_mailer.with(invoice:).created

        expect(mailer.to).to be_nil
      end
    end

    context "when invoice fees amount is zero" do
      before do
        invoice.update(fees_amount_cents: 0)
      end

      it "returns a mailer with nil values" do
        mailer = invoice_mailer.with(invoice:).created

        expect(mailer.to).to be_nil
      end
    end
  end
end
