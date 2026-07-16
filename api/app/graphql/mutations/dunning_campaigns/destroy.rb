# frozen_string_literal: true

module Mutations
  module DunningCampaigns
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "dunning_campaigns:delete"

      graphql_name "DestroyDunningCampaign"
      description "Deletes a dunning campaign"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        dunning_campaign = current_organization.dunning_campaigns.find_by(id:)
        result = ::DunningCampaigns::DestroyService.call(dunning_campaign:)

        result.success? ? result.dunning_campaign : result_error(result)
      end
    end
  end
end
