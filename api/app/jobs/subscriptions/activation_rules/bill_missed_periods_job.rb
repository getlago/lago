# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class BillMissedPeriodsJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
          :billing
        else
          :default
        end
      end

      retry_on Sequenced::SequenceError, wait: :polynomially_longer, attempts: 15, jitter: 0.75
      retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

      retry_on Customers::FailedToAcquireLock, ActiveRecord::StaleObjectError, attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay

      unique :until_executed, on_conflict: :log

      def perform(subscription)
        Subscriptions::ActivationRules::BillMissedPeriodsService.call!(subscription:)
      end
    end
  end
end
