# frozen_string_literal: true

require "csv"
require "forwardable"

module DataExports
  module Csv
    class CreditNotes < BaseCsvService
      extend Forwardable

      def initialize(data_export_part:, serializer_klass: V1::CreditNoteSerializer)
        @data_export_part = data_export_part
        @serializer_klass = serializer_klass
        super
      end

      def self.base_headers
        %w[
          lago_id
          sequential_id
          partner_billing
          issuing_date
          customer_lago_id
          customer_external_id
          customer_name
          customer_email
          customer_country
          customer_tax_identification_number
          number
          invoice_number
          purchase_order_number
          credit_status
          refund_status
          reason
          description
          currency
          total_amount_cents
          taxes_amount_cents
          sub_total_excluding_taxes_amount_cents
          coupons_adjustment_amount_cents
          offset_amount_cents
          credit_amount_cents
          balance_amount_cents
          refund_amount_cents
          file_url
        ]
      end

      def headers
        base = self.class.base_headers.dup
        base << "billing_entity_code" if org_has_multiple_billing_entities?
        base
      end

      private

      attr_reader :data_export_part, :serializer_klass

      def serialize_item(credit_note, csv)
        serialized_note = serializer_klass.new(credit_note, includes: %i[customer]).serialize

        row = [
          serialized_note[:lago_id],
          serialized_note[:sequential_id],
          serialized_note[:self_billed],
          serialized_note[:issuing_date],
          serialized_note.dig(:customer, :lago_id),
          serialized_note.dig(:customer, :external_id),
          serialized_note.dig(:customer, :name),
          serialized_note.dig(:customer, :email),
          serialized_note.dig(:customer, :country),
          serialized_note.dig(:customer, :tax_identification_number),
          serialized_note[:number],
          serialized_note[:invoice_number],
          serialized_note[:purchase_order_number],
          serialized_note[:credit_status],
          serialized_note[:refund_status],
          serialized_note[:reason],
          serialized_note[:description],
          serialized_note[:currency],
          serialized_note[:total_amount_cents],
          serialized_note[:taxes_amount_cents],
          serialized_note[:sub_total_excluding_taxes_amount_cents],
          serialized_note[:coupons_adjustment_amount_cents],
          serialized_note[:offset_amount_cents],
          serialized_note[:credit_amount_cents],
          serialized_note[:balance_amount_cents],
          serialized_note[:refund_amount_cents],
          serialized_note[:file_url]
        ]
        row << serialized_note[:billing_entity_code] if org_has_multiple_billing_entities?
        csv << row
      end

      def collection
        CreditNote.includes(:customer).find(data_export_part.object_ids)
      end

      def organization
        @organization ||= data_export_part.data_export.organization
      end

      def org_has_multiple_billing_entities?
        return false unless organization

        organization.billing_entities.count > 1
      end
    end
  end
end
