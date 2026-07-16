# frozen_string_literal: true

module Invoices
  # NOTE: A plan can have tens of thousands of active subscriptions; iterating
  #       and enqueuing one job per subscription is delegated to a single job
  #       to keep synchronous requests fast.
  class CreateAllPayInAdvanceFixedChargesJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :default
      end
    end

    unique :until_executed, on_conflict: :log

    def perform(plan, timestamp, fixed_charge = nil)
      subscriptions = plan.subscriptions.active
      if fixed_charge
        subscriptions = subscriptions.without_fixed_charge_units_override_for(fixed_charge)
      end

      subscriptions.find_each do |subscription|
        Invoices::CreatePayInAdvanceFixedChargesJob.perform_later(subscription, timestamp)
      end
    end
  end
end
