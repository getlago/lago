# frozen_string_literal: true

module OrderForms
  class MarkAsSignedService < BaseService
    include OrderForms::Premium
    include OrderForms::ExecutionSettingsValidation

    Result = BaseResult[:order_form, :order]

    def initialize(order_form:, signed_document: nil, execution_mode: nil, execute_at: nil)
      @order_form = order_form
      @signed_document = signed_document
      @execution_mode = execution_mode
      @execute_at = execute_at

      super
    end

    activity_loggable(
      action: "order_form.signed",
      record: -> { order_form }
    )

    def call
      return result.not_found_failure!(resource: "order_form") unless order_form
      return result.forbidden_failure! unless order_forms_enabled?(order_form.organization)

      validate_execution_settings
      return result if result.failure?

      attachment = signed_document_attachment
      return result if result.failure?

      OrderForm.transaction do
        Quotes::LockService.call(quote: order_form.quote_version.quote) do
          order_form.reload
          next result.single_validation_failure!(field: :status, error_code: "not_signable") unless order_form.generated?

          order_form.assign_attributes(
            status: :signed,
            signed_at: Time.current
          )
          order_form.signed_document.attach(attachment) if attachment
          order_form.save!

          result.order = Order.create!(
            organization: order_form.organization,
            customer: order_form.customer,
            order_form:,
            execution_mode:,
            execute_at:
          )

          # TODO: Enqueue Orders::ExecuteOrderJob.perform_after_commit(result.order) when execution_mode == "execute_in_lago"

          result.order_form = order_form
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :order_form_id, error_code: "value_already_exist")
    end

    private

    attr_reader :order_form, :signed_document, :execution_mode, :execute_at

    def validate_execution_settings
      validate_execution_mode(execution_mode:, execute_at:)
      return if result.failure?

      validate_execute_at(execute_at:)
    end

    def signed_document_attachment
      return if signed_document.blank?

      decoded = Utils::Base64File.decode(signed_document)

      if decoded.nil?
        result.single_validation_failure!(field: :signed_document, error_code: "invalid_format")
        return
      end

      {
        io: decoded.io,
        filename: order_form.number,
        content_type: decoded.content_type
      }
    end
  end
end
