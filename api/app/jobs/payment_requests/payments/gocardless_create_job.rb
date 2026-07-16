# frozen_string_literal: true

module PaymentRequests
  module Payments
    class GocardlessCreateJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      unique :until_executed, on_conflict: :log

      def perform(payable)
        # NOTE: Legacy job, kept only to avoid faileure with existing jobs

        PaymentRequests::Payments::CreateService.call!(payable:, payment_provider: "gocardless")
      end
    end
  end
end
