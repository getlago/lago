# frozen_string_literal: true

module Mutations
  module DunningCampaigns
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "dunning_campaigns:update"

      graphql_name "UpdateDunningCampaign"
      description "Updates a dunning campaign and its thresholds"

      input_object_class Types::DunningCampaigns::UpdateInput
      type Types::DunningCampaigns::Object

      def resolve(**args)
        dunning_campaign = current_organization.dunning_campaigns.find_by(id: args[:id])

        result = ::DunningCampaigns::UpdateService.call(
          organization: current_organization,
          dunning_campaign:,
          params: args
        )

        result.success? ? result.dunning_campaign : result_error(result)
      end
    end
  end
end
