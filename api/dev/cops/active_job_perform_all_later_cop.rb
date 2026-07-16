# frozen_string_literal: true

require "rubocop"

module Cops
  # `ActiveJob.perform_all_later` bypasses the `before_enqueue` callbacks used by
  # `activejob-uniqueness` to acquire uniqueness locks. This means unique jobs scheduled
  # via `perform_all_later` silently skip uniqueness checks, potentially causing duplicate
  # job execution.
  #
  # Use `ApplicationJob.perform_all_later` instead, which includes a runtime guard that
  # raises an `ArgumentError` if any of the jobs have uniqueness enabled.
  class ActiveJobPerformAllLaterCop < ::RuboCop::Cop::Base
    MSG = "Avoid using `ActiveJob.perform_all_later`. Use `ApplicationJob.perform_all_later` instead."

    def_node_matcher :active_job_perform_all_later?, <<~PATTERN
      (send (const nil? :ActiveJob) :perform_all_later ...)
    PATTERN

    def self.badge
      @badge ||= ::RuboCop::Cop::Badge.for("Lago/ActiveJobPerformAllLater") # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def on_send(node)
      return unless active_job_perform_all_later?(node)

      add_offense(node)
    end
  end
end
