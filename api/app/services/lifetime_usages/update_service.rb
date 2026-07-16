# frozen_string_literal: true

module LifetimeUsages
  class UpdateService < BaseService
    Result = BaseResult[:lifetime_usage]

    def initialize(lifetime_usage:, params:)
      @lifetime_usage = lifetime_usage
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: "lifetime_usage") unless lifetime_usage

      lifetime_usage.update!(historical_usage_amount_cents: params[:external_historical_usage_amount_cents])

      result.lifetime_usage = lifetime_usage
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :lifetime_usage, :params
  end
end
