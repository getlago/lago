# frozen_string_literal: true

require "csv"
require "forwardable"

module DataExports
  module Csv
    class CreditNoteItems < BaseCsvService
      extend Forwardable

      def initialize(data_export_part:, serializer_klass: V1::CreditNoteItemSerializer)
        @data_export_part = data_export_part
        @serializer_klass = serializer_klass
        super
      end

      def self.base_headers
        %w[
          credit_note_lago_id
          credit_note_number
          credit_note_invoice_number
          credit_note_issuing_date
          credit_note_item_lago_id
          credit_note_item_fee_lago_id
          credit_note_item_currency
          credit_note_item_amount_cents
        ]
      end

      def headers
        self.class.base_headers.dup
      end

      private

      attr_reader :data_export_part, :serializer_klass

      def serialize_item(credit_note_item, csv)
        serialized_item = serializer_klass.new(credit_note_item).serialize

        serialized_note = {
          lago_id: credit_note_item.credit_note.id,
          number: credit_note_item.credit_note.number,
          invoice_number: credit_note_item.credit_note.invoice.number,
          issuing_date: credit_note_item.credit_note.issuing_date.iso8601
        }

        csv << [
          serialized_note[:lago_id],
          serialized_note[:number],
          serialized_note[:invoice_number],
          serialized_note[:issuing_date],
          serialized_item[:lago_id],
          serialized_item.dig(:fee, :lago_id),
          serialized_item[:amount_currency],
          serialized_item[:amount_cents]
        ]
      end

      def collection
        CreditNoteItem
          .includes(:credit_note, :fee)
          .where(credit_note_id: data_export_part.object_ids)
      end
    end
  end
end
