# frozen_string_literal: true

module SentryCronConcern
  extend ActiveSupport::Concern

  included do
    include Sentry::Cron::MonitorCheckIns

    class_attribute :sentry # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    after_perform do
      if ENV["SENTRY_ENABLE_CRONS"] && self.class.sentry.present?
        self.class.sentry_monitor_check_ins(
          slug: self.class.sentry["slug"],
          monitor_config: Sentry::Cron::MonitorConfig.from_crontab(self.class.sentry["cron"])
        )
      end
    end

    def serialize
      super.tap do |data|
        data["sentry"] = self.class.sentry if self.class.sentry.present?
      end
    end

    def deserialize(job_data)
      super
      self.class.sentry = job_data["sentry"]
    end
  end

  class_methods do
    def set(options)
      if ENV["SENTRY_ENABLE_CRONS"] && options[:sentry].present?
        self.sentry = options[:sentry]
      end

      super
    end
  end
end
