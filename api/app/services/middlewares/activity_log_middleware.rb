# frozen_string_literal: true

module Middlewares
  class ActivityLogMiddleware < BaseMiddleware
    def call(&block)
      if produce_activity_log?
        log_kwargs = {after_commit:}.compact

        case action
        when /updated/
          Utils::ActivityLog.produce(record, action, **log_kwargs) { call_next(&block) }

        else
          call_next(&block).tap do |result|
            Utils::ActivityLog.produce(record, action, **log_kwargs) { result }
          end
        end
      else
        call_next(&block)
      end
    end

    def produce_activity_log?
      return false if kwargs.nil?

      service_instance.instance_exec(&kwargs[:condition])
    end

    def action
      kwargs[:action]
    end

    def after_commit
      kwargs[:after_commit]
    end

    def record
      service_instance.instance_exec(&kwargs[:record])
    end
  end
end
