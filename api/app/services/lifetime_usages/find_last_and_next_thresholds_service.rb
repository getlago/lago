# frozen_string_literal: true

module LifetimeUsages
  class FindLastAndNextThresholdsService < BaseService
    Result = BaseResult[:last_threshold_amount_cents, :next_threshold_amount_cents, :next_threshold_ratio]

    def initialize(lifetime_usage:)
      @lifetime_usage = lifetime_usage

      super
    end

    def call
      completion_result = LifetimeUsages::UsageThresholdsCompletionService.call(lifetime_usage:).raise_if_error!

      index = completion_result.usage_thresholds.rindex { |h| h[:reached_at].present? }
      passed_threshold = nil
      next_threshold = nil

      if index
        passed_threshold = completion_result.usage_thresholds[index]
        next_threshold = completion_result.usage_thresholds[index + 1]
      else
        next_threshold = completion_result.usage_thresholds.first
      end

      result.last_threshold_amount_cents = passed_threshold&.[](:amount_cents)
      result.next_threshold_amount_cents = next_threshold&.[](:amount_cents)
      result.next_threshold_ratio = next_threshold&.[](:completion_ratio)
      result
    end

    private

    attr_reader :lifetime_usage
  end
end
