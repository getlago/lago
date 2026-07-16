# frozen_string_literal: true

module Types
  module DunningCampaigns
    class Object < Types::BaseObject
      graphql_name "DunningCampaign"

      field :id, ID, null: false

      field :applied_to_organization, Boolean, null: false
      field :bcc_emails, [String], null: true
      field :code, String, null: false
      field :customers_count, Integer, null: false
      field :days_between_attempts, Integer, null: false
      field :max_attempts, Integer, null: false
      field :name, String, null: false
      field :thresholds, [Types::DunningCampaignThresholds::Object], null: false

      field :description, String, null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      def applied_to_organization
        object.organization.default_billing_entity.applied_dunning_campaign_id == object.id
      end

      # rubocop:disable GraphQL/ResolverMethodLength
      def customers_count
        Customer.where(
          <<~SQL.squish,
            exclude_from_dunning_campaign = false
            AND (
              applied_dunning_campaign_id = :campaign_id
              OR (
                applied_dunning_campaign_id IS NULL
                AND billing_entity_id IN (:billing_entity_ids)
              )
            )
          SQL
          campaign_id: object.id,
          billing_entity_ids: object.billing_entities.ids
        ).count
      end
      # rubocop:enable GraphQL/ResolverMethodLength
    end
  end
end
