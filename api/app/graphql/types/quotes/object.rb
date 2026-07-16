# frozen_string_literal: true

module Types
  module Quotes
    class Object < Types::BaseObject
      graphql_name "Quote"

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :current_version, Types::QuoteVersions::Object, null: false
      field :customer, Types::Customers::Object, null: false
      field :id, ID, null: false
      field :images, GraphQL::Types::JSON, null: false
      field :number, String, null: false
      field :order_type, Types::Quotes::OrderTypeEnum, null: false
      field :organization, Types::Organizations::OrganizationType, null: false
      field :owners, [Types::UserType], null: true
      field :subscription, Types::Subscriptions::Object, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      field :versions, [Types::QuoteVersions::Object], null: false

      dataload_association :customer, :organization, :subscription, :owners, :versions, :current_version

      def images
        dataloader.with(Sources::ActiveRecordAssociation, :images_blobs).load(object).each_with_object({}) do |blob, urls|
          urls[blob.id] = Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV["LAGO_API_URL"])
        end
      end
    end
  end
end
