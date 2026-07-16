# frozen_string_literal: true

module OrderForms
  class ExpireOrderFormJob < ApplicationJob
    queue_as :default

    unique :until_executed, on_conflict: :log

    retry_on Customers::FailedToAcquireLock, attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay

    def perform(order_form)
      OrderForms::ExpireService.call!(order_form:)
    end
  end
end
