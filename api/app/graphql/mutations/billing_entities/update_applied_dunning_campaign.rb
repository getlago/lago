# frozen_string_literal: true

module Mutations
  module BillingEntities
    class UpdateAppliedDunningCampaign < ::Mutations::BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "billing_entities:update"

      graphql_name "BillingEntityUpdateAppliedDunningCampaign"
      description "Updates the applied dunning campaign for a billing entity"

      argument :applied_dunning_campaign_id, String, required: false
      argument :billing_entity_id, ID, required: true

      type Types::BillingEntities::Object

      def resolve(billing_entity_id:, applied_dunning_campaign_id:)
        billing_entity = current_organization.billing_entities.find_by(id: billing_entity_id)
        result = ::BillingEntities::UpdateAppliedDunningCampaignService.call(billing_entity:, applied_dunning_campaign_id:)

        result.success? ? result.billing_entity : result_error(result)
      end
    end
  end
end
