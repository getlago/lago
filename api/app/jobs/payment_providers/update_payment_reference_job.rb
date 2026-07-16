# frozen_string_literal: true

module PaymentProviders
  class UpdatePaymentReferenceJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
        :payments
      else
        :providers
      end
    end

    def perform(payment)
      PaymentProviders::UpdatePaymentReferenceService.call!(payment:)
    end
  end
end
