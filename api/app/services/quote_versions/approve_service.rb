# frozen_string_literal: true

module QuoteVersions
  class ApproveService < BaseService
    include OrderForms::Premium

    attr_reader :quote_version, :expires_at

    Result = BaseResult[:quote_version, :order_form]

    def initialize(quote_version:, expires_at: nil)
      @quote_version = quote_version
      @expires_at = expires_at
      super
    end

    def call
      return result.not_found_failure!(resource: "quote_version") unless quote_version
      return result.forbidden_failure! unless order_forms_enabled?(quote_version.organization)

      QuoteVersion.transaction do
        Quotes::LockService.call(quote: quote_version.quote) do
          quote_version.reload
          next result.single_validation_failure!(field: :status, error_code: "not_approvable") unless approvable?

          quote_version.update!(
            status: :approved,
            approved_at: Time.current,
            mention_variables: ComputeMentionVariablesService.call!(quote_version:).mention_variables
          )

          result.order_form = OrderForms::CreateService.call!(quote_version:, expires_at:).order_form
          result.quote_version = quote_version
        end
      end

      # TODO: SendWebhookJob.perform_after_commit("quote_version.approved", quote_version)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::ValidationFailure => e
      e.result
    end

    private

    def approvable?
      quote_version.draft?
    end
  end
end
