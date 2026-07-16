# frozen_string_literal: true

module OrderForms
  class VoidService < BaseService
    include OrderForms::Premium

    Result = BaseResult[:order_form]

    def initialize(order_form:)
      @order_form = order_form

      super
    end

    activity_loggable(
      action: "order_form.voided",
      record: -> { order_form }
    )

    def call
      return result.not_found_failure!(resource: "order_form") unless order_form
      return result.forbidden_failure! unless order_forms_enabled?(order_form.organization)

      OrderForm.transaction do
        Quotes::LockService.call(quote: order_form.quote_version.quote) do
          order_form.reload
          next result.single_validation_failure!(field: :status, error_code: "not_voidable") unless order_form.generated?

          order_form.update!(
            status: :voided,
            voided_at: Time.current,
            void_reason: :manual
          )

          QuoteVersions::VoidService.call!(quote_version: order_form.quote_version, reason: :cascade_of_voided)

          result.order_form = order_form
        end
      end

      result
    end

    private

    attr_reader :order_form
  end
end
