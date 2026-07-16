# frozen_string_literal: true

module Sources
  # GraphQL DataLoader source for batch loading memberships by role IDs.
  #
  # Prevents N+1 queries when fetching memberships for multiple roles
  # in a single GraphQL query (e.g., `roles { memberships { ... } }`).
  #
  # Loads all membership_roles for the given role IDs in a single query,
  # then groups them by role_id to return the correct memberships for each role.
  #
  # Usage in GraphQL types:
  #   dataloader.with(Sources::MembershipsForRole, current_organization).load(role.id)
  #
  class MembershipsForRole < GraphQL::Dataloader::Source
    def initialize(organization)
      @organization = organization
    end

    def fetch(role_ids)
      membership_roles = MembershipRole
        .joins(:membership)
        .includes(:membership)
        .where(role_id: role_ids, organization: @organization)
        .merge(Membership.active)

      memberships_by_role = membership_roles.group_by(&:role_id).transform_values do |mrs|
        mrs.map(&:membership)
      end

      role_ids.map { |role_id| memberships_by_role[role_id].to_a }
    end
  end
end
