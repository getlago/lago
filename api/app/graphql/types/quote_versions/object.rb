# frozen_string_literal: true

module Types
  module QuoteVersions
    class Object < Types::BaseObject
      graphql_name "QuoteVersion"

      field :approved_at, GraphQL::Types::ISO8601DateTime, null: true
      field :billing_items, GraphQL::Types::JSON, null: true
      field :content, String, null: true
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :currency, String, null: true
      field :end_date, GraphQL::Types::ISO8601Date, null: true
      field :id, ID, null: false
      field :mention_variables, GraphQL::Types::JSON, null: false
      field :organization, Types::Organizations::OrganizationType, null: false
      field :quote, Types::Quotes::Object, null: false
      field :share_token, String, null: true
      field :start_date, GraphQL::Types::ISO8601Date, null: true
      field :status, Types::QuoteVersions::StatusEnum, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      field :version, Integer, null: false
      field :void_reason, Types::QuoteVersions::VoidReasonEnum, null: true
      field :voided_at, GraphQL::Types::ISO8601DateTime, null: true
      # TODO: field :order_form, Types::OrderForms::Object, null: true

      dataload_association :organization, :quote

      # The persisted snapshot is a raw, locale-independent dict (or computed live while the
      # version is editable). It is localized on every read with the customer's current
      # locale, so an approved quote re-renders in the customer's current language.
      #
      # Intended for single-record fetches: live computation walks quote -> customer ->
      # billing_entity, which are not dataloaded beyond :quote. Requesting mention_variables
      # across a `versions` collection would N+1; dataload that chain here if such an access
      # pattern emerges.
      def mention_variables
        raw = object.mention_variables.presence ||
          ::QuoteVersions::ComputeMentionVariablesService.call(quote_version: object).mention_variables

        ::QuoteVersions::MentionVariablesLocalizer.call(
          mention_variables: raw,
          locale: object.quote.customer.preferred_document_locale
        )
      end
    end
  end
end
