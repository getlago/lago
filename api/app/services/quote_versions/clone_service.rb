# frozen_string_literal: true

module QuoteVersions
  class CloneService < BaseService
    include OrderForms::Premium

    class CloneError < StandardError
      attr_reader :source_result

      def initialize(source_result:)
        @source_result = source_result
        super("QuoteVersion clone failed: #{source_result&.error&.message}")
      end
    end

    attr_reader :quote_version

    Result = BaseResult[:quote_version]

    def initialize(quote_version:)
      @quote_version = quote_version
      super
    end

    def call
      return result.not_found_failure!(resource: "quote_version") unless quote_version
      return result.forbidden_failure! unless order_forms_enabled?(quote_version.organization)

      QuoteVersion.transaction do
        Quotes::LockService.call(quote: quote_version.quote) do
          quote_version.reload
          next result.single_validation_failure!(field: :status, error_code: "not_clonable") unless clonable?

          void_active_version!
          result.quote_version = create_next_version(quote_version:)
        end
      end

      # TODO: SendWebhookJob.perform_after_commit("quote_version.cloned", result.quote_version)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :status, error_code: "active_version_exists")
    rescue CloneError => e
      result.service_failure!(code: "clone_failed", message: e.message, error: e)
    end

    private

    def clonable?
      !quote_version.quote.versions.approved.exists?
    end

    def create_next_version(quote_version:)
      quote_version.dup.tap do |cloned|
        cloned.status = :draft
        cloned.sequential_id = nil
        cloned.share_token = nil # regenerated on save
        cloned.void_reason = nil
        cloned.voided_at = nil
        cloned.approved_at = nil
        cloned.save!
      end
    end

    def void_active_version!
      # At most one draft exists per quote. If the version being cloned is that
      # draft, void it directly; only look it up when cloning a non-draft (e.g.
      # an older voided version while a newer draft is the active one).
      active_draft = quote_version.draft? ? quote_version : quote_version.quote.versions.find_by(status: :draft)
      return if active_draft.nil?

      void_result = QuoteVersions::VoidService.new(
        quote_version: active_draft,
        reason: :superseded
      ).call

      raise CloneError.new(source_result: void_result) unless void_result&.success?
    end
  end
end
