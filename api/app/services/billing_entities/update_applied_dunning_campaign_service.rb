# frozen_string_literal: true

module BillingEntities
  class UpdateAppliedDunningCampaignService < BaseService
    Result = BaseResult[:billing_entity]
    def initialize(billing_entity:, applied_dunning_campaign_id: nil)
      @billing_entity = billing_entity
      @applied_dunning_campaign_id = applied_dunning_campaign_id
      super
    end

    def call
      return result.not_found_failure!(resource: "billing_entity") if billing_entity.nil?
      return if billing_entity.applied_dunning_campaign_id == applied_dunning_campaign_id

      old_campaign = billing_entity.applied_dunning_campaign
      dunning_campaign = DunningCampaign.find(applied_dunning_campaign_id) if applied_dunning_campaign_id
      billing_entity.reset_customers_last_dunning_campaign_attempt
      billing_entity.update!(applied_dunning_campaign: dunning_campaign)

      register_security_log(old_campaign, dunning_campaign)

      result.billing_entity = billing_entity
      result
    rescue ActiveRecord::RecordNotFound
      result.not_found_failure!(resource: "dunning_campaign")
    end

    private

    attr_reader :billing_entity, :applied_dunning_campaign_id

    def register_security_log(old_campaign, new_campaign)
      Utils::SecurityLog.produce(
        organization: billing_entity.organization,
        log_type: "billing_entity",
        log_event: "billing_entity.updated",
        resources: {
          billing_entity_name: billing_entity.name,
          billing_entity_code: billing_entity.code,
          applied_dunning_campaign: {deleted: old_campaign&.code, added: new_campaign&.code}.compact
        }
      )
    end
  end
end
