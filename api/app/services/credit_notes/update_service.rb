# frozen_string_literal: true

module CreditNotes
  class UpdateService < BaseService
    Result = BaseResult[:credit_note]

    def initialize(credit_note:, partial_metadata: false, **params)
      @params = params&.with_indifferent_access
      @credit_note = credit_note
      @refund_status = @params[:refund_status]
      @partial_metadata = partial_metadata

      super
    end

    def call
      return result.not_found_failure!(resource: "credit_note") if credit_note.nil? || credit_note.draft?

      ActiveRecord::Base.transaction do
        if update_refund_status?
          credit_note.refund_status = refund_status
          credit_note.refunded_at = Time.current if credit_note.succeeded?
        end

        update_metadata!
        if credit_note.changed?
          credit_note.save!
        elsif metadata_changed
          credit_note.touch # rubocop:disable Rails/SkipsModelValidations
        end
      end

      handle_changes

      result.credit_note = credit_note
      result
    rescue ArgumentError
      result.single_validation_failure!(field: :refund_status, error_code: "value_is_invalid")
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :credit_note, :params, :refund_status, :metadata_changed, :partial_metadata

    def update_refund_status?
      params.key?(:refund_status)
    end

    # @return [Boolean] if the metadata was changed in any way
    def update_metadata!
      return unless params.key?(:metadata)

      value = params[:metadata]&.then { |m| m.respond_to?(:to_unsafe_h) ? m.to_unsafe_h : m.to_h }
      metadata_result = Metadata::UpdateItemService.call!(owner: credit_note, value:, partial: partial_metadata.present?)
      @metadata_changed = metadata_result.metadata_changed
    end

    def handle_changes
      if credit_note.previous_changes.key?(:refund_status)
        Utils::SegmentTrack.refund_status_changed(credit_note.refund_status, credit_note.id, credit_note.organization.id)
      end
    end
  end
end
