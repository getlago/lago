# frozen_string_literal: true

module EInvoices
  module CreditNotes::Ubl
    class CreateService < ::BaseService
      def initialize(credit_note:)
        super

        @credit_note = credit_note
      end

      def call
        return result.not_found_failure!(resource: "credit_note") unless credit_note

        result.xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          EInvoices::CreditNotes::Ubl::Builder.serialize(xml:, credit_note:)
        end.to_xml

        result
      end

      private

      attr_accessor :credit_note
    end
  end
end
