# frozen_string_literal: true

module PaymentReceipts
  class NotifyJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :low_priority
      end
    end

    def perform(payment_receipt:)
      PaymentReceiptMailer.with(payment_receipt:).created.deliver_later
    end
  end
end
