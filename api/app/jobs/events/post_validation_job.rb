# frozen_string_literal: true

module Events
  class PostValidationJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_EVENTS"])
        :events
      else
        :default
      end
    end

    def perform(organization:)
      Events::PostValidationService.call(organization:)
    end
  end
end
