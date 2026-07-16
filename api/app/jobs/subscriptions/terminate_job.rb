# frozen_string_literal: true

module Subscriptions
  class TerminateJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :default
      end
    end

    def perform(subscription, timestamp)
      result = Subscriptions::TerminateService.new(subscription:)
        .terminate_and_start_next(timestamp:)

      result.raise_if_error!
    end
  end
end
