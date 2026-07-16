# frozen_string_literal: true

module Metadata
  # Remove a key from an existing metadata.
  # Return an error result if the metadata has already been deleted.
  class DeleteItemKeyService < BaseService
    Result = BaseResult[:item, :metadata_changed]

    # @option [Metadata::MetadataItem] :item The metadata item to modify
    # @option [#to_s] :key The key of the metadata item to delete
    def initialize(item:, key:)
      @item = item
      @key = key.to_s

      super()
    end

    def call
      item.update!(value: item.value.to_h.except(key))

      result.item = item
      result.metadata_changed = item.previous_changes.any?
      result
    rescue ActiveRecord::RecordNotFound
      result.not_found_failure!(resource: "metadata_item")
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :item, :key
  end
end
