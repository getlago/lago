# frozen_string_literal: true

module Events
  # DEPRECATED
  class CreateBatchJob < ApplicationJob
    queue_as :default

    def perform(organization, params, timestamp, metadata)
      result = Events::CreateBatchService.new.call(
        organization:,
        params:,
        timestamp: Time.zone.at(timestamp.to_f),
        metadata:
      )

      result.raise_if_error!
    end
  end
end
