# frozen_string_literal: true

module Invoices
  module Payments
    class MarkOverdueJob < ApplicationJob
      unique :until_executed, on_conflict: :log
      queue_as do
        :low_priority
      end

      def perform(invoice:)
        MarkOverdueService.call(invoice:)
      end
    end
  end
end
