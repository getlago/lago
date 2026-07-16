# frozen_string_literal: true

module PaymentReceipts
  class CreateJob < ApplicationJob
    queue_as :low_priority

    def perform(payment)
      PaymentReceipts::CreateService.call!(payment:)
    end
  end
end
