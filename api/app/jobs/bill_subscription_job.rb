# frozen_string_literal: true

class BillSubscriptionJob < ApplicationJob
  queue_as do
    if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
      :billing
    else
      :default
    end
  end

  unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

  retry_on Customers::FailedToAcquireLock, ActiveRecord::StaleObjectError, attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay
  retry_on Sequenced::SequenceError, ActiveJob::DeserializationError, wait: :polynomially_longer, attempts: 15, jitter: 0.75

  def perform(subscriptions, timestamp, invoicing_reason:, invoice: nil, skip_charges: false)
    Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - Started")

    result = Invoices::SubscriptionService.call(
      subscriptions:,
      timestamp:,
      invoicing_reason:,
      invoice:,
      skip_charges:
    )

    if result.success?
      Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - Finished [SUCCESS]")
      return
    end

    Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - Before reload [#{result.invoice&.inspect}]")
    result.invoice&.reload
    Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - After reload [#{result.invoice&.inspect}]")

    # If the invoice was passed as an argument, it means the job was already retried (see end of function)
    if invoice || !result.invoice&.generating?
      Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - generating?: #{result.invoice&.generating?}")

      ErrorDetail.create_generation_error_for(invoice: result.invoice, error: result.error)
      Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - Raising error: #{result.error.inspect}")
      return result.raise_if_error!
    end

    # On billing day, we'll retry the job further in the future because the system is typically under heavy load
    is_billing_date = invoicing_reason.to_sym == :subscription_periodic

    Rails.logger.info("BillSubscriptionJob[Invoice ID: #{invoice&.id}] - Retrying with invoice")

    self.class.set(wait: is_billing_date ? 5.minutes : 3.seconds).perform_later(
      subscriptions,
      timestamp,
      invoicing_reason:,
      invoice: result.invoice,
      skip_charges:
    )
  end

  # Each hour, we check for each customer whether they need to be billed today. If it is the case and there's not
  # invoice for today in the DB, we will schedule the BillSubscriptionJob with timestamp of the current time. So it
  # could occur that we schedule a second job while the first one (from one hour ago) hasn't been processed yet due to a
  # high number of jobs. As the timestamp won't be the same, the lock key would be different and both jobs could be
  # processed concurrently, causing unnecessary jobs. Note that even if the job is schduled twice, we'll still prevent
  # duplicate invoices.
  #
  # To avoid this, we normalize the timestamp in the customer's timezone and use the date as the lock key argument.
  def lock_key_arguments
    arguments = self.arguments.dup

    # if there is no subscription, we don't need to normalize anything
    return arguments if arguments[0].empty?
    timestamp = arguments[1]
    subscriptions = arguments[0]

    # BillSubscriptionJob subscriptions will always contain subscriptions for the same customer
    customer = subscriptions.first.customer
    date = Time.zone.at(timestamp).in_time_zone(customer.applicable_timezone).to_date
    arguments[1] = date
    arguments
  end
end
