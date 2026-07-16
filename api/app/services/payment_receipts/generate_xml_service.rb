# frozen_string_literal: true

module PaymentReceipts
  class GenerateXmlService < BaseService
    Result = BaseResult[:payment_receipt]

    def initialize(payment_receipt:, context: nil)
      @payment_receipt = payment_receipt
      @context = context

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_receipt") if payment_receipt.blank?

      if should_generate_xml?
        generate_xml
      end

      result.payment_receipt = payment_receipt
      result
    end

    private

    attr_reader :payment_receipt, :context

    def generate_xml
      I18n.with_locale(payment_receipt.customer.preferred_document_locale) do
        xml_file = build_xml_file
        attach_xml_to_payment_receipt(xml_file)
        payment_receipt.save!
      ensure
        cleanup_tempfiles(xml_file)
      end
    end

    def build_xml_file
      xml_file = Tempfile.new([payment_receipt.number, ".xml"])
      xml_file.write(EInvoices::Payments::Ubl::CreateService.call(payment: payment_receipt.payment).xml)
      xml_file.flush

      xml_file
    end

    def attach_xml_to_payment_receipt(xml_file)
      payment_receipt.xml_file.attach(
        io: File.open(xml_file.path),
        filename: "#{payment_receipt.number}.xml",
        content_type: "application/xml"
      )
    end

    def cleanup_tempfiles(xml_file)
      xml_file&.unlink
    end

    def should_generate_xml?
      return true if context == "admin"

      payment_receipt.xml_file.blank? && e_invoicing_enabled?
    end

    def e_invoicing_enabled?
      payment_receipt.billing_entity.eligible_for_einvoicing?
    end
  end
end
