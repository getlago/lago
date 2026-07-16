# frozen_string_literal: true

module Invoices
  module Metadata
    class UpdateService < BaseService
      Result = BaseResult[:invoice]

      def initialize(invoice:, params:)
        @invoice = invoice
        @params = params
        super
      end

      def call
        created_metadata_ids = []

        hash_metadata = params.map { |m| m.to_h.deep_symbolize_keys }
        hash_metadata.each do |payload_metadata|
          metadata = invoice.metadata.find_by(id: payload_metadata[:id])

          if metadata
            metadata.update!(payload_metadata)

            next
          end

          created_metadata = create_metadata(payload_metadata)
          created_metadata_ids.push(created_metadata.id)
        end

        # NOTE: Delete metadata that are no more linked to the invoice
        sanitize_metadata(hash_metadata, created_metadata_ids)

        result.invoice = invoice
        result
      end

      private

      attr_reader :invoice, :params

      def create_metadata(payload)
        invoice.metadata.create!(
          organization_id: invoice.organization_id,
          key: payload[:key],
          value: payload[:value]
        )
      end

      def sanitize_metadata(args_metadata, created_metadata_ids)
        updated_metadata_ids = args_metadata.reject { |m| m[:id].nil? }.map { |m| m[:id] }
        not_needed_ids = invoice.metadata.pluck(:id) - updated_metadata_ids - created_metadata_ids

        invoice.metadata.where(id: not_needed_ids).destroy_all
      end
    end
  end
end
