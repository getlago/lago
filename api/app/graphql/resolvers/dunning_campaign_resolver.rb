# frozen_string_literal: true

module Resolvers
  class DunningCampaignResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query a single dunning campaign of an organization"

    REQUIRED_PERMISSION = "dunning_campaigns:view"

    argument :id, ID, required: true, description: "Unique ID of the dunning campaign"

    type Types::DunningCampaigns::Object, null: false

    def resolve(id: nil)
      current_organization.dunning_campaigns.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "dunning_campaign")
    end
  end
end
