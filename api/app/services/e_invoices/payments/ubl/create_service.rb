# frozen_string_literal: true

module EInvoices
  module Payments::Ubl
    class CreateService < ::BaseService
      def initialize(payment:)
        super

        @payment = payment
      end

      def call
        return result.not_found_failure!(resource: "payment") unless payment
        return result.forbidden_failure! unless payment.organization.issue_receipts_enabled?

        result.xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          EInvoices::Payments::Ubl::Builder.serialize(xml:, payment:)
        end.to_xml

        result
      end

      private

      attr_accessor :payment
    end
  end
end
