# frozen_string_literal: true

module Customers
  # Kept for backward compatibility with jobs already enqueued under the old name.
  # Previously this job received a customer ID string; the new ViesCheckJob expects
  # a Customer object (GlobalID). This class bridges the old signature.
  class RetryViesCheckJob < ApplicationJob
    queue_as :default

    def perform(customer_id)
      customer = Customer.find(customer_id)

      ViesCheckJob.perform_now(customer)
    end
  end
end
