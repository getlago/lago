# frozen_string_literal: true

module Utils
  module DedicatedWorkerConfig
    DEDICATED_WALLETS_QUEUE = :dedicated_wallets
    DEDICATED_ALERTS_QUEUE = :dedicated_alerts

    ORGANIZATION_IDS = ENV["LAGO_DEDICATED_WORKER_ORG_IDS"].to_s.split(",").map(&:strip).reject(&:empty?).each(&:downcase).freeze

    def self.refresh_interval
      interval = ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"].presence.to_i
      (interval.positive? ? interval : 5).seconds
    end

    def self.organization_ids
      ORGANIZATION_IDS
    end

    def self.enabled_for?(organization_id)
      return false if organization_id.blank?

      ORGANIZATION_IDS.include?(organization_id.downcase.to_s)
    end

    def self.any?
      ORGANIZATION_IDS.any?
    end
  end
end
