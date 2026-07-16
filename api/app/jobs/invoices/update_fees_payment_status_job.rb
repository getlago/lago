# frozen_string_literal: true

module Invoices
  class UpdateFeesPaymentStatusJob < ApplicationJob
    queue_as "invoices"

    def perform(invoice)
      invoice.fees.update!(payment_status: invoice.payment_status)
    end
  end
end
