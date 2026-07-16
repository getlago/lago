# frozen_string_literal: true

module EInvoices
  module Invoices::Ubl
    class CreateService < ::BaseService
      def initialize(invoice:)
        super

        @invoice = invoice
      end

      def call
        return result.not_found_failure!(resource: "invoice") unless invoice

        result.xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          ::EInvoices::Invoices::Ubl::Builder.serialize(xml:, invoice:)
        end.to_xml

        result
      end

      private

      attr_accessor :invoice
    end
  end
end
