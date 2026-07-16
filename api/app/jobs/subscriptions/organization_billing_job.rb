# frozen_string_literal: true

module Subscriptions
  class OrganizationBillingJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_CLOCK"])
        :clock_worker
      else
        :clock
      end
    end

    unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

    def perform(organization:)
      Subscriptions::OrganizationBillingService.call!(organization:)
    end
  end
end
