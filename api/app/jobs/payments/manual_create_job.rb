# frozen_string_literal: true

module Payments
  class ManualCreateJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
        :payments
      else
        :low_priority
      end
    end

    def perform(organization:, params:)
      Payments::ManualCreateService.call!(organization:, params:)
    end
  end
end
