# frozen_string_literal: true

module Memberships
  class RevokeService < BaseService
    Result = BaseResult[:membership]

    def initialize(user:, membership:)
      @user = user
      @membership = membership

      super
    end

    def call
      return result.not_found_failure!(resource: "membership") unless membership
      return result.not_allowed_failure!(code: "cannot_revoke_own_membership") if user.id == membership.user.id
      return result.not_allowed_failure!(code: "last_admin") if membership.admin? && membership.organization.admin_membership_roles.count == 1

      membership.mark_as_revoked!
      register_security_log

      result.membership = membership
      result
    end

    private

    attr_reader :user, :membership

    def register_security_log
      Utils::SecurityLog.produce(
        organization: membership.organization,
        log_type: "user",
        log_event: "user.deleted",
        user: user,
        resources: {email: membership.user.email}
      )
    end
  end
end
