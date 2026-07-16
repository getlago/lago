# frozen_string_literal: true

module EInvoices
  module Ubl
    class BaseSerializer < EInvoices::BaseSerializer
      COMMON_NAMESPACES = {
        "xmlns:cac" => "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
        "xmlns:cbc" => "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
      }

      INVOICE_NAMESPACES = {
        "xmlns" => "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
      }.merge(COMMON_NAMESPACES).freeze

      CREDIT_NOTE_NAMESPACES = {
        "xmlns" => "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2"
      }.merge(COMMON_NAMESPACES).freeze

      RECEIPTS_NAMESPACES = {
        "xmlns" => "urn:oasis:names:specification:ubl:schema:xsd:ApplicationResponse-2"
      }.merge(COMMON_NAMESPACES).freeze

      DATEFORMAT = "%Y-%m-%d"

      EN16931_PROFILE = "urn:cen.eu:en16931:2017"
      XRECHNUNG_3_0_PROFILE = "#{EN16931_PROFILE}#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0".freeze
      PEPPOL_BIS_BILLING_PROFILE = "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0"

      private

      def de_billing_entity?
        resource.billing_entity.country.try(:upcase) == "DE"
      end

      def customization_id
        de_billing_entity? ? XRECHNUNG_3_0_PROFILE : EN16931_PROFILE
      end
    end
  end
end
