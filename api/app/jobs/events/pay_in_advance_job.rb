# frozen_string_literal: true

module Events
  class PayInAdvanceJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_EVENTS"])
        :events
      else
        :default
      end
    end

    unique :until_executed, on_conflict: :log

    def perform(event)
      Events::PayInAdvanceService.call!(event:)
    end

    def lock_key_arguments
      event = Events::CommonFactory.new_instance(source: arguments.first)
      [event.organization_id, event.external_subscription_id, event.transaction_id]
    end
  end
end
