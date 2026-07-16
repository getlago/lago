# frozen_string_literal: true

module DailyUsages
  class FillHistoryJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_ANALYTICS"])
        :analytics_low_priority
      else
        :long_running
      end
    end

    retry_on DailyUsages::RetryableError, wait: :polynomially_longer, attempts: 6

    def perform(subscription:, from_date:, to_date: nil, sandbox: false)
      DailyUsages::FillHistoryService.call!(subscription:, from_date:, to_date:, sandbox:)
    rescue ActiveRecord::ActiveRecordError => e
      raise DailyUsages::RetryableError, e.message if e.message.include?("end of file reached")

      raise
    end
  end
end
