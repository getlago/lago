# frozen_string_literal: true

module CreditNotes
  class GenerateXmlService < BaseService
    def initialize(credit_note:, context: nil)
      @credit_note = credit_note
      @context = context

      super
    end

    def call
      return result.not_found_failure!(resource: "credit_note") if credit_note.blank?
      return result.not_allowed_failure!(code: "is_draft") if credit_note.draft?

      if should_generate_xml?
        generate_xml
      end

      result.credit_note = credit_note
      result
    end

    private

    attr_reader :credit_note, :context

    def generate_xml
      I18n.with_locale(credit_note.customer.preferred_document_locale) do
        xml_file = build_xml_file
        attach_xml_to_credit_note(xml_file)
        credit_note.save!
      ensure
        cleanup_tempfiles(xml_file)
      end
    end

    def build_xml_file
      xml_file = Tempfile.new([credit_note.number, ".xml"])
      xml_file.write(EInvoices::CreditNotes::Ubl::CreateService.call(credit_note:).xml)
      xml_file.flush

      xml_file
    end

    def attach_xml_to_credit_note(xml_file)
      credit_note.xml_file.attach(
        io: File.open(xml_file.path),
        filename: "#{credit_note.number}.xml",
        content_type: "application/xml"
      )
    end

    def cleanup_tempfiles(xml_file)
      xml_file&.unlink
    end

    def should_generate_xml?
      return true if context == "admin"

      credit_note.xml_file.blank? && e_invoicing_enabled?
    end

    def e_invoicing_enabled?
      credit_note.billing_entity.eligible_for_einvoicing?
    end
  end
end
