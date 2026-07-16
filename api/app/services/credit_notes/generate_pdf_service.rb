# frozen_string_literal: true

module CreditNotes
  class GeneratePdfService < BaseService
    def initialize(credit_note:, context: nil)
      @credit_note = credit_note
      @context = context

      super
    end

    def call
      return result.not_found_failure!(resource: "credit_note") if credit_note.blank? || !credit_note.finalized?

      if should_generate_pdf?
        generate_pdf(credit_note)
        SendWebhookJob.perform_later("credit_note.generated", credit_note)
        Utils::ActivityLog.produce(credit_note, "credit_note.generated")
      end

      result.credit_note = credit_note
      result
    end

    private

    attr_reader :credit_note, :context

    def generate_pdf(credit_note)
      I18n.with_locale(credit_note.customer.preferred_document_locale) do
        pdf_file = build_pdf_file
        xml_file = attach_cii(pdf_file) if should_generate_cii_einvoice_xml?
        attach_pdf_to_credit_note(pdf_file)

        credit_note.save!
      ensure
        cleanup_tempfiles(pdf_file, xml_file)
      end
    end

    def build_pdf_file
      pdf_content = Utils::PdfGenerator.call(template:, context: credit_note).io.read

      pdf_file = Tempfile.new([credit_note.number, ".pdf"])
      pdf_file.binmode
      pdf_file.write(pdf_content)
      pdf_file.flush

      pdf_file
    end

    def attach_cii(pdf_file)
      xml_file = Tempfile.new([credit_note.number, ".xml"])
      xml_file.write(EInvoices::CreditNotes::Cii::CreateService.call(credit_note:).xml)
      xml_file.flush

      Utils::PdfAttachmentService.call(file: pdf_file, attachment: xml_file)
      xml_file
    end

    def attach_pdf_to_credit_note(pdf_file)
      credit_note.file.attach(
        io: File.open(pdf_file.path),
        filename: "#{credit_note.number}.pdf",
        content_type: "application/pdf"
      )
    end

    def cleanup_tempfiles(pdf_file, xml_file)
      pdf_file&.unlink
      xml_file&.unlink
    end

    def should_generate_cii_einvoice_xml?
      credit_note.billing_entity.eligible_for_einvoicing?
    end

    def should_generate_pdf?
      return false if ActiveModel::Type::Boolean.new.cast(ENV["LAGO_DISABLE_PDF_GENERATION"])

      context == "admin" || credit_note.file.blank?
    end

    def template
      return "credit_notes/self_billed" if credit_note.invoice.self_billed?

      "credit_notes/credit_note"
    end
  end
end
