# frozen_string_literal: true

module BillableMetrics
  class UpdateService < BaseService
    Result = BaseResult[:billable_metric]

    def initialize(billable_metric:, params:)
      @billable_metric = billable_metric
      @params = params

      super
    end

    activity_loggable(
      action: "billable_metric.updated",
      record: -> { billable_metric }
    )

    def call
      return result.not_found_failure!(resource: "billable_metric") unless billable_metric

      if params.key?(:aggregation_type) &&
          params[:aggregation_type]&.to_sym == :custom_agg &&
          !organization&.custom_aggregation
        return result.forbidden_failure!
      end

      billable_metric.with_lock do
        billable_metric.name = params[:name] if params.key?(:name)
        billable_metric.description = params[:description] if params.key?(:description)

        if params.key?(:filters)
          BillableMetricFilters::CreateOrUpdateBatchService.call(
            billable_metric:,
            filters_params: params[:filters].map { |f| f.to_h.with_indifferent_access }
          ).raise_if_error!
        end

        # NOTE: Only name and description are editable if billable metric
        #       is attached to a plan
        unless billable_metric.attached_to_plan?
          billable_metric.code = params[:code] if params.key?(:code)
          billable_metric.aggregation_type = params[:aggregation_type]&.to_sym if params.key?(:aggregation_type)
          billable_metric.weighted_interval = params[:weighted_interval]&.to_sym if params.key?(:weighted_interval)
          billable_metric.field_name = params[:field_name] if params.key?(:field_name)
          billable_metric.recurring = params[:recurring] if params.key?(:recurring)
          billable_metric.rounding_function = params[:rounding_function] if params.key?(:rounding_function)
          billable_metric.rounding_precision = params[:rounding_precision] if params.key?(:rounding_precision)
          billable_metric.weighted_interval = params[:weighted_interval]&.to_sym if params.key?(:weighted_interval)
          billable_metric.expression = params[:expression] if params.key?(:expression)

          if params.key?(:expression) || params.key?(:field_name)
            BillableMetrics::ExpressionCacheService.expire_cache(organization.id, billable_metric.code)
          end
        end

        billable_metric.save!
      end

      SendWebhookJob.perform_after_commit("billable_metric.updated", billable_metric)

      result.billable_metric = billable_metric
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :billable_metric, :params

    delegate :organization, to: :billable_metric
  end
end
