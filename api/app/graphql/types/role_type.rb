# frozen_string_literal: true

module Types
  class RoleType < Types::BaseObject
    field :admin, Boolean, null: false
    field :code, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :description, String, null: true
    field :id, ID, null: false
    field :memberships, [Types::MembershipType], null: false
    field :name, String, null: false
    field :permissions, [PermissionEnum], null: false

    def memberships
      dataloader
        .with(Sources::MembershipsForRole, context[:current_organization])
        .load(object.id)
    end

    def permissions
      object.permissions_hash.filter_map { |k, v| k if v }
    end
  end
end
