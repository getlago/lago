# frozen_string_literal: true

module Invoices
  class GenerateXmlService < BaseService
    def initialize(invoice:, context: nil)
      @invoice = invoice
      @context = context

      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") if invoice.blank?
      return result.not_allowed_failure!(code: "is_draft") if invoice.draft?

      if should_generate_xml?
        generate_xml
      end

      result.invoice = invoice
      result
    end

    private

    attr_reader :invoice, :context

    def generate_xml
      I18n.with_locale(invoice.customer.preferred_document_locale) do
        xml_file = build_xml_file
        attach_xml_to_invoice(xml_file)
        invoice.save!
      ensure
        cleanup_tempfiles(xml_file)
      end
    end

    def build_xml_file
      xml_file = Tempfile.new([invoice.number, ".xml"])
      xml_file.write(EInvoices::Invoices::Ubl::CreateService.call(invoice:).xml)
      xml_file.flush

      xml_file
    end

    def attach_xml_to_invoice(xml_file)
      invoice.xml_file.attach(
        io: File.open(xml_file.path),
        filename: "#{invoice.number}.xml",
        content_type: "application/xml"
      )
    end

    def cleanup_tempfiles(xml_file)
      xml_file&.unlink
    end

    def should_generate_xml?
      return true if context == "admin"

      invoice.xml_file.blank? && e_invoicing_enabled?
    end

    def e_invoicing_enabled?
      invoice.billing_entity.eligible_for_einvoicing?
    end
  end
end
