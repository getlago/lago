# frozen_string_literal: true

module OrderForms
  class CreateService < BaseService
    include OrderForms::Premium

    Result = BaseResult[:order_form]

    def initialize(quote_version:, expires_at: nil)
      @quote_version = quote_version
      @expires_at = expires_at
      super
    end

    def call
      return result.not_found_failure!(resource: "quote_version") unless quote_version
      return result.forbidden_failure! unless order_forms_enabled?(quote_version.organization)
      return result.single_validation_failure!(field: :quote_version, error_code: "not_approved") unless quote_version.approved?
      return result.single_validation_failure!(field: :expires_at, error_code: "invalid_date") unless valid_expires_at?

      order_form = OrderForm.create!(
        organization: quote_version.organization,
        customer: quote_version.quote.customer,
        quote_version:,
        status: :generated,
        expires_at:
      )

      result.order_form = order_form
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :quote_version_id, error_code: "value_already_exist")
    end

    private

    attr_reader :quote_version, :expires_at

    def valid_expires_at?
      Validators::ExpirationDateValidator.valid?(expires_at)
    end
  end
end
