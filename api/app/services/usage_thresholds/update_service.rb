# frozen_string_literal: true

module UsageThresholds
  class UpdateService < BaseService
    Result = BaseResult

    def initialize(model:, usage_thresholds_params:, partial:)
      @model = model
      @usage_thresholds_params = sanitize_params(usage_thresholds_params)
      @partial = partial

      super
    end

    def call
      return result if usage_thresholds_params.empty? && partial?

      return result.single_validation_failure!(error_code: "missing_amount_cents", field: :usage_thresholds) if missing_amount_cents?
      return result.single_validation_failure!(error_code: "duplicated_values", field: :usage_thresholds) if duplicated_amount_cents?
      return result.single_validation_failure!(error_code: "multiple_recurring_thresholds", field: :usage_thresholds) if multiple_recurring_thresholds?

      ActiveRecord::Base.transaction do
        delete_all_thresholds if full?

        update_recurring_threshold
        update_or_create_thresholds
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :model, :usage_thresholds_params, :partial
    alias_method :partial?, :partial

    def full?
      !partial
    end

    def sanitize_params(usage_thresholds_params)
      usage_thresholds_params.map do |p|
        h = p.to_h.deep_symbolize_keys.slice(:threshold_display_name, :amount_cents, :recurring)
        h[:recurring] ||= false
        h
      end
    end

    def missing_amount_cents?
      usage_thresholds_params.any? { |p| p[:amount_cents].blank? }
    end

    def duplicated_amount_cents?
      grouped = usage_thresholds_params.group_by { |p| [p[:amount_cents], p[:recurring]] }
      grouped.any? { |_, v| v.size > 1 }
    end

    def multiple_recurring_thresholds?
      usage_thresholds_params.count { |p| p[:recurring] } > 1
    end

    def delete_all_thresholds
      model.usage_thresholds.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def update_recurring_threshold
      recurring_params = usage_thresholds_params.find { |p| p[:recurring] }
      return unless recurring_params

      existing_threshold = model.usage_thresholds.find { |t| t.recurring }

      if existing_threshold
        existing_threshold.update!(
          amount_cents: recurring_params[:amount_cents],
          threshold_display_name: recurring_params[:threshold_display_name]
        )
      else
        create_threshold(recurring_params, recurring: true)
      end
    end

    def update_or_create_thresholds
      usage_thresholds_params.reject { |p| p[:recurring] }.each do |threshold_params|
        existing_threshold = model.usage_thresholds.find { |t| t.amount_cents == threshold_params[:amount_cents] && !t.recurring }

        if existing_threshold
          update_threshold(existing_threshold, threshold_params)
        else
          create_threshold(threshold_params)
        end
      end
    end

    def update_threshold(threshold, params)
      threshold.threshold_display_name = params[:threshold_display_name] if params.key?(:threshold_display_name)
      threshold.save!
    end

    def create_threshold(params, recurring: false)
      model.usage_thresholds.create!(
        organization: model.organization,
        threshold_display_name: params[:threshold_display_name],
        amount_cents: params[:amount_cents],
        recurring:
      )
    end
  end
end
