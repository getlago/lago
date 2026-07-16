# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false

    field :email, String
    field :premium, Boolean, null: false

    field :memberships, [Types::MembershipType], null: false
    # TODO: keeping organization for backwards compatibility, remove once the frontend is updated
    field :organizations, [Types::Organizations::OrganizationType], null: false

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def memberships
      object.memberships.active.includes(:organization)
    end

    def organizations
      memberships.map(&:organization)
    end

    def premium
      License.premium?
    end
  end
end
