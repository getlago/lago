# frozen_string_literal: true

require "active_job/uniqueness/strategies/until_executed"

# https://github.com/veeqo/activejob-uniqueness/issues/75
# retry_on does not work with until_executed strategy

module ActiveJob
  module Uniqueness
    module Strategies
      module UntilExecutedPatch
        def before_enqueue
          return if lock(resource: lock_key, ttl: lock_ttl)
          # We're retrying the job, so we don't need to lock again
          return if job.executions > 0

          handle_conflict(resource: lock_key, on_conflict: on_conflict)
          abort_job
        end
      end
    end
  end
end

ActiveJob::Uniqueness::Strategies::UntilExecuted.prepend(
  ActiveJob::Uniqueness::Strategies::UntilExecutedPatch
)
