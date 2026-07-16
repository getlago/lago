# frozen_string_literal: true

module Orders
  class UpdateService < BaseService
    include OrderForms::Premium
    include OrderForms::ExecutionSettingsValidation

    Result = BaseResult[:order]

    def initialize(order:, params:)
      @order = order
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: "order") unless order
      return result.forbidden_failure! unless order_forms_enabled?(order.organization)

      validate_execution_settings
      return result if result.failure?

      Order.transaction do
        Quotes::LockService.call(quote: order.quote) do
          order.reload
          unless order.created?
            result.single_validation_failure!(field: :status, error_code: "not_editable")
            result.raise_if_error!
          end

          order.assign_attributes(params.slice(:execution_mode, :execute_at))
          order.save!

          result.order = order
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :order, :params

    def effective_execution_mode
      params.key?(:execution_mode) ? params[:execution_mode] : order.execution_mode
    end

    def effective_execute_at
      params.key?(:execute_at) ? params[:execute_at] : order.execute_at
    end

    def validate_execution_settings
      validate_execution_mode(execution_mode: effective_execution_mode, execute_at: effective_execute_at)
      return if result.failure?

      validate_execute_at(execute_at: params[:execute_at])
    end
  end
end
