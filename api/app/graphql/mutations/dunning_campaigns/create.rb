# frozen_string_literal: true

module Mutations
  module DunningCampaigns
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "dunning_campaigns:create"

      graphql_name "CreateDunningCampaign"
      description "Creates a new dunning campaign"

      input_object_class Types::DunningCampaigns::CreateInput

      type Types::DunningCampaigns::Object

      def resolve(**args)
        result = ::DunningCampaigns::CreateService.call(organization: current_organization, params: args)
        result.success? ? result.dunning_campaign : result_error(result)
      end
    end
  end
end
