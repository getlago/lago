# frozen_string_literal: true

module Metadata
  # Updates the metadata of the record with new content, creates it if absent, or deletes it.
  #
  # It behaves differently based on the `partial` flag and the content of the old and new value:
  # ```
  # ----------+-----------+---------+-------------------------
  # old value | new value | partial | action
  # ----------+-----------+---------+-------------------------
  #   nil     |    nil    |   any   | no-op
  #   nil     |   non-nil |   any   | set new value
  #  non-nil  |    nil    |  false  | delete metadata item
  #  non-nil  |    nil    |  true   | no-op
  #  non-nil  |   non-nil |  false  | replace with new value
  #  non-nil  |   non-nil |  true   | merge new value
  # ----------+-----------+---------+-------------------------
  # ```
  #
  # The service can change the metadata in the database,
  # and its `result` contains the updated metadata item
  # to check if the operation was successful.
  class UpdateItemService < BaseService
    Result = BaseResult[:metadata, :metadata_changed]

    # @param [ActiveRecord::Base] owner The record whose metadata is to be updated
    # @option [#to_h] :value The new content of the metadata item
    # @option [Boolean] :partial Whether to merge the existing content (replace by default)
    def initialize(owner:, value:, partial: false)
      @value = value
      @owner = owner
      @partial = partial

      super()
    end

    def call
      if create_metadata?
        owner.create_metadata!(organization_id:, value:)
      elsif replace_metadata?
        metadata.update!(value:)
      elsif merge_metadata?
        metadata.update!(value: metadata.value.merge(value))
      elsif delete_metadata?
        metadata.destroy!
      end

      result.metadata = metadata
      result.metadata_changed = (metadata&.previous_changes&.any? || metadata&.destroyed?).present?
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :owner, :value, :partial
    delegate :metadata, :organization_id, to: :owner

    def create_metadata?
      owner.metadata.blank? && !value.nil? && (value.present? || !partial)
    end

    def replace_metadata?
      owner.metadata.present? && !partial && !value.nil?
    end

    def merge_metadata?
      owner.metadata.present? && partial && value.present?
    end

    def delete_metadata?
      owner.metadata.present? && !partial && value.nil?
    end
  end
end
