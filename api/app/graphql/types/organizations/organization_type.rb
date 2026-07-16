# frozen_string_literal: true

module Types
  module Organizations
    # This type is used to expose organization information to users that
    # are potentially not members of that organization. It's used where the organization
    # is a relationship on the other object.
    # It cannot expose any sensitive fields like `api_key` because there is a risk of GraphQL traversal attack.
    #
    # Only the `CurrentOrganizationType` can expose sensitive fields.
    #
    # Ex: current organization > memberships > another member > organizations can lead to an organization
    #     the current user is not supposed to have access to
    class OrganizationType < BaseOrganizationType
      description "Safe Organization Type"

      field :id, ID, null: false

      field :default_currency, Types::CurrencyEnum, null: false
      field :logo_url, String
      field :name, String, null: false
      field :slug, String, null: false
      field :timezone, Types::TimezoneEnum, null: true

      field :accessible_by_current_session, Boolean, null: false

      field :billing_configuration, Types::Organizations::BillingConfiguration, null: true

      field :can_create_billing_entity, Boolean, null: false, method: :can_create_billing_entity?

      def accessible_by_current_session
        return false if context[:current_user].nil?

        context[:current_user].organizations.include?(object) &&
          object.authentication_methods.include?(context[:login_method])
      end
    end
  end
end
