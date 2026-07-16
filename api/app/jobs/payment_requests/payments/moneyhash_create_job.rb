# frozen_string_literal: true

module PaymentRequests
  module Payments
    class MoneyhashCreateJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      unique :until_executed

      def perform(payable)
        result = PaymentRequests::Payments::MoneyhashService.new(payable).create
        result.raise_if_error!
      end
    end
  end
end
