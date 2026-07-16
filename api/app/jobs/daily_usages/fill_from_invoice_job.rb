# frozen_string_literal: true

module DailyUsages
  class FillFromInvoiceJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_ANALYTICS"])
        :analytics
      else
        :low_priority
      end
    end

    def perform(invoice:, subscriptions:)
      DailyUsages::FillFromInvoiceService.call(invoice:, subscriptions:).raise_if_error!
    end
  end
end
