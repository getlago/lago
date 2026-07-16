# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  sidekiq_options retry: 0

  MAX_LOCK_RETRY_ATTEMPTS = 25
  MAX_LOCK_RETRY_DELAY = 16 # seconds

  # This is a generic error to trigger the retry of any job
  # The max attempt is set to avoid infinite loops
  retry_on RetriableError, wait: :polynomially_longer, attempts: 20

  # This method is used to perform a job after a commit.
  #
  # It is meant to avoid race-conditions where a job run before changes are committed to the DB and we end up with stale
  # data in the job.
  #
  # It is also possible to rely on `ActiveJob::Base.enqueue_after_transaction_commit` but this doesn't allow incremental
  # changes.
  #
  # Note that this method is not compatible with configured jobs, e.g.
  # `Invoices::UpdateFeesPaymentStatusJob.set(wait: 30.seconds).perform_later(invoice)`.
  #
  def self.perform_after_commit(...)
    AfterCommitEverywhere.after_commit do
      perform_later(...)
    end
  end

  # This method wraps ActiveJob.perform_all_later with a runtime check to ensure
  # that none of the jobs have uniqueness enabled, as perform_all_later bypasses
  # the before_enqueue callbacks used by activejob-uniqueness.
  #
  def self.perform_all_later(jobs)
    unique_jobs = jobs.select { |job| job.class.lock_strategy_class }
    if unique_jobs.any?
      raise ArgumentError, "perform_all_later is not compatible with unique jobs: #{unique_jobs.map { |j| j.class.name }.uniq.join(", ")}"
    end

    ActiveJob.perform_all_later(jobs) # rubocop:disable Lago/ActiveJobPerformAllLater
  end

  # This method is a generic proc for specifying random wait between retries
  # Usage:
  # retry_on ExceptionClass, attempts: 5, wait: random_delay(16)
  #
  def self.random_delay(max_seconds)
    ->(*) { rand(0...max_seconds) }
  end

  # This method is a generic proc for using with lock retry attempts
  # Usage:
  # retry_on ExceptionClass, attempts: 5, wait: random_lock_retry_delay
  #
  def self.random_lock_retry_delay
    random_delay(MAX_LOCK_RETRY_DELAY)
  end
end
