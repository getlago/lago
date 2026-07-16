# frozen_string_literal: true

module QuoteVersions
  class UpdateService < BaseService
    include OrderForms::Premium

    attr_reader :quote_version, :params

    Result = BaseResult[:quote_version]

    def initialize(quote_version:, params:)
      @quote_version = quote_version
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "quote_version") unless quote_version
      return result.forbidden_failure! unless order_forms_enabled?(quote_version.organization)
      return result.single_validation_failure!(field: :status, error_code: "not_editable") unless editable?

      quote_version.update!(
        params.slice(
          :billing_items,
          :content,
          :currency,
          :start_date,
          :end_date
        )
      )
      result.quote_version = quote_version

      # TODO: SendWebhookJob.perform_after_commit("quote_version.updated", quote_version)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    def editable?
      quote_version.draft?
    end
  end
end
