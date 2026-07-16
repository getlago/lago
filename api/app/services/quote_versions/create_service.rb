# frozen_string_literal: true

module QuoteVersions
  class CreateService < BaseService
    include OrderForms::Premium

    attr_reader :quote, :params

    Result = BaseResult[:quote_version]

    def initialize(quote:, params: {})
      @quote = quote
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "quote") unless quote
      return result.forbidden_failure! unless order_forms_enabled?(quote.organization)
      return result.forbidden_failure!(code: "active_version_exists") if active_version_exists?

      quote_version = quote.versions.create!(
        organization: quote.organization,
        **params.slice(
          :billing_items,
          :content,
          :currency,
          :start_date,
          :end_date
        )
      )

      result.quote_version = quote_version

      # TODO: SendWebhookJob.perform_after_commit("quote_version.created", quote_version)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.forbidden_failure!(code: "active_version_exists")
    end

    private

    def active_version_exists?
      quote.versions.where(status: %w[draft approved]).exists?
    end
  end
end
