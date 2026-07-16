# frozen_string_literal: true

module DunningCampaigns
  class DestroyService < BaseService
    Result = BaseResult[:dunning_campaign]

    def initialize(dunning_campaign:)
      @dunning_campaign = dunning_campaign

      super
    end

    def call
      return result.not_found_failure!(resource: "dunning_campaign") unless dunning_campaign
      return result.forbidden_failure! unless dunning_campaign.organization.auto_dunning_enabled?

      # rubocop:disable Rails/SkipsModelValidations
      ActiveRecord::Base.transaction do
        dunning_campaign.reset_customers_last_attempt
        dunning_campaign.discard!
        dunning_campaign.thresholds.update_all(deleted_at: Time.current)
        dunning_campaign.customers.update_all(applied_dunning_campaign_id: nil)
        dunning_campaign.billing_entities.update_all(applied_dunning_campaign_id: nil)
      end
      # rubocop:enable Rails/SkipsModelValidations

      result.dunning_campaign = dunning_campaign
      result
    end

    private

    attr_reader :dunning_campaign
  end
end
