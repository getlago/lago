# frozen_string_literal: true

module Events
  class PostProcessJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_EVENTS"])
        :events
      else
        :default
      end
    end

    def perform(event:)
      Events::PostProcessService.call(event:).raise_if_error!
    end
  end
end
