# frozen_string_literal: true

require "csv"
require "forwardable"

module DataExports
  module Csv
    class InvoiceFees < BaseCsvService
      extend Forwardable

      def initialize(
        data_export_part:,
        invoice_serializer_klass: V1::InvoiceSerializer,
        fee_serializer_klass: V1::FeeSerializer
      )
        @data_export_part = data_export_part
        @invoice_serializer_klass = invoice_serializer_klass
        @fee_serializer_klass = fee_serializer_klass
        super
      end

      def self.base_headers
        %w[
          invoice_lago_id
          invoice_number
          invoice_issuing_date
          fee_lago_id
          fee_item_type
          fee_item_code
          fee_item_name
          fee_item_description
          fee_item_invoice_display_name
          fee_item_filter_invoice_display_name
          fee_item_grouped_by
          subscription_external_id
          subscription_plan_code
          fee_from_date_utc
          fee_to_date_utc
          fee_amount_currency
          fee_units
          fee_precise_unit_amount
          fee_taxes_amount_cents
          fee_total_amount_cents
        ]
      end

      def headers
        self.class.base_headers.dup
      end

      private

      attr_reader :data_export_part, :invoice_serializer_klass, :fee_serializer_klass

      def serialize_item(invoice, csv)
        serialized_invoice = invoice_serializer_klass.new(invoice).serialize

        invoice
          .fees
          .includes(
            :invoice,
            :subscription,
            :charge,
            :true_up_fee,
            :customer,
            :billable_metric,
            {charge_filter: {values: :billable_metric_filter}}
          )
          .find_each
          .lazy
          .each do |fee|
            serialized_fee = fee_serializer_klass.new(fee).serialize

            serialized_subscription = {
              external_id: fee.subscription&.external_id,
              plan_code: fee.subscription&.plan&.code
            }

            csv << [
              serialized_invoice[:lago_id],
              serialized_invoice[:number],
              serialized_invoice[:issuing_date],
              serialized_fee[:lago_id],
              serialized_fee.dig(:item, :type),
              serialized_fee.dig(:item, :code),
              serialized_fee.dig(:item, :name),
              serialized_fee.dig(:item, :description),
              serialized_fee.dig(:item, :invoice_display_name),
              serialized_fee.dig(:item, :filter_invoice_display_name),
              serialized_fee.dig(:item, :grouped_by),
              serialized_subscription[:external_id],
              serialized_subscription[:plan_code],
              serialized_fee[:from_date],
              serialized_fee[:to_date],
              serialized_fee[:total_amount_currency],
              serialized_fee[:units],
              serialized_fee[:precise_unit_amount],
              serialized_fee[:taxes_amount_cents],
              serialized_fee[:total_amount_cents]
            ]
        end
      end

      def collection
        Invoice.find(data_export_part.object_ids)
      end
    end
  end
end
