# frozen_string_literal: true

module PaymentReceipts
  class GeneratePdfService < BaseService
    def initialize(payment_receipt:, context: nil)
      @payment_receipt = payment_receipt
      @context = context

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_receipt") if payment_receipt.blank?

      if should_generate_pdf?
        generate_pdf
        SendWebhookJob.perform_later("payment_receipt.generated", payment_receipt)
        Utils::ActivityLog.produce(payment_receipt, "payment_receipt.generated")
      end

      result.payment_receipt = payment_receipt
      result
    end

    def render_html
      Utils::PdfGenerator.new(template:, context: payment_receipt).render_html
    end

    private

    attr_reader :payment_receipt, :context

    def generate_pdf
      I18n.with_locale(payment_receipt.payment.customer.preferred_document_locale) do
        pdf_file = build_pdf_file
        xml_file = attach_cii(pdf_file) if should_generate_cii_einvoice_xml?
        attach_pdf_to_payment_receipt(pdf_file)
        payment_receipt.save!
      ensure
        cleanup_tempfiles(pdf_file, xml_file)
      end
    end

    def build_pdf_file
      pdf_content = Utils::PdfGenerator.call(template:, context: payment_receipt).io.read

      pdf_file = Tempfile.new([payment_receipt.number, ".pdf"])
      pdf_file.binmode
      pdf_file.write(pdf_content)
      pdf_file.flush

      pdf_file
    end

    def attach_cii(pdf_file)
      xml_file = Tempfile.new([payment_receipt.number, ".xml"])
      xml_file.write(EInvoices::Payments::Cii::CreateService.call(payment: payment_receipt.payment).xml)
      xml_file.flush

      Utils::PdfAttachmentService.call(file: pdf_file, attachment: xml_file)
      xml_file
    end

    def attach_pdf_to_payment_receipt(pdf_file)
      payment_receipt.file.attach(
        io: File.open(pdf_file.path),
        filename: "#{payment_receipt.number}.pdf",
        content_type: "application/pdf"
      )
    end

    def should_generate_cii_einvoice_xml?
      payment_receipt.billing_entity.eligible_for_einvoicing?
    end

    def should_generate_pdf?
      return false if ActiveModel::Type::Boolean.new.cast(ENV["LAGO_DISABLE_PDF_GENERATION"])

      context == "admin" || payment_receipt.file.blank?
    end

    def cleanup_tempfiles(pdf_file, xml_file)
      pdf_file&.unlink
      xml_file&.unlink
    end

    def template
      "payment_receipts/v1"
    end
  end
end
