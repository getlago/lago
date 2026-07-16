# frozen_string_literal: true

module DataExports
  class ExportResourcesService < BaseService
    Result = BaseResult[:data_export, :data_export_parts]

    EXPIRED_FAILURE_MESSAGE = "Data Export already expired"
    PROCESSED_FAILURE_MESSAGE = "Data Export already processed"
    DEFAULT_BATCH_SIZE = 20

    ResourceTypeNotSupportedError = Class.new(StandardError)

    extend Forwardable

    def_delegators :data_export, :organization, :resource_query, :resource_type, :format

    def initialize(data_export:, batch_size: DEFAULT_BATCH_SIZE)
      @data_export = data_export
      @batch_size = batch_size

      super
    end

    def call
      return result.service_failure!(code: "data_export_expired", message: EXPIRED_FAILURE_MESSAGE) if data_export.expired?
      return result.service_failure!(code: "data_export_processed", message: PROCESSED_FAILURE_MESSAGE) unless data_export.pending?

      data_export.processing!
      result.data_export = data_export
      result.data_export_parts = []

      data_export.transaction do
        all_object_ids.each_slice(batch_size).with_index do |object_ids, index|
          part_result = DataExports::CreatePartService.call(data_export:, object_ids:, index:).raise_if_error!
          result.data_export_parts << part_result.data_export_part
        end
      end

      result
    rescue => e
      data_export.failed!
      result.service_failure!(code: e.message, message: e.full_message)
    end

    private

    attr_reader :data_export, :batch_size

    def all_object_ids
      case resource_type
      when "credit_notes", "credit_note_items" then credit_note_ids
      when "invoices", "invoice_fees" then all_invoice_ids
      else
        raise ResourceTypeNotSupportedError.new(
          "'#{resource_type}' resource not supported"
        )
      end
    end

    def all_invoice_ids
      search_term = resource_query["search_term"]
      filters = resource_query.except("search_term")

      InvoicesQuery.call(
        organization:,
        pagination: nil,
        search_term:,
        filters:
      ).invoices.pluck(:id).uniq
    end

    def credit_note_ids
      search_term = resource_query["search_term"]
      filters = resource_query.except("search_term")

      CreditNotesQuery.call(
        organization:,
        pagination: nil,
        search_term:,
        filters:
      ).credit_notes.pluck(:id).uniq
    end
  end
end
