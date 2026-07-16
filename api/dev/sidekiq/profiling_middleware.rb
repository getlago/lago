# frozen_string_literal: true

require "vernier"

module Sidekiq
  # ProfilingMiddleware is a Sidekiq server middleware that profiles the execution of each Sidekiq job using the Vernier profiler.
  #
  # See docs/profiling.md for more information.
  class ProfilingMiddleware
    def initialize(options = {})
      @dir = options.fetch(:dir, "tmp/profiling")
    end

    def call(_instance, hash, queue, &block)
      job_dir = "#{dir}/#{hash["wrapped"] || hash["class"]}"
      FileUtils.mkdir_p(job_dir)

      file_path = "#{job_dir}/#{Time.at(hash["enqueued_at"]).iso8601}-#{hash["jid"]}.json"

      result = nil

      Vernier.profile(out: file_path) do
        result = yield
      end

      result
    end

    private

    attr_reader :dir
  end
end
