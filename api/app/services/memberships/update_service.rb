# frozen_string_literal: true

module Memberships
  class UpdateService < BaseService
    Result = BaseResult[:membership]

    def initialize(user:, membership:, params:)
      @user = user
      @membership = membership
      @params = params

      super
    end

    def call
      ActiveRecord::Base.transaction do
        return result.not_found_failure!(resource: "membership") unless membership
        return result.not_found_failure!(resource: "role") if new_roles.blank?
        return result.forbidden_failure!(code: "cannot_grant_admin") if granting_admin_without_being_admin?
        return result.not_allowed_failure!(code: "last_admin") if last_admin_demotion?

        roles_to_remove = old_roles - new_roles
        (new_roles - old_roles).each { |role| MembershipRole.create!(organization:, membership:, role:) }
        MembershipRole.where(membership:, role: roles_to_remove).discard_all! if roles_to_remove.present?
      end

      register_security_log

      result.membership = membership.reload
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :user, :membership, :params

    def register_security_log
      old_codes = old_roles.map(&:code)
      new_codes = new_roles.map(&:code)
      entry = {}
      deleted = old_codes - new_codes
      added = new_codes - old_codes
      entry[:deleted] = deleted if deleted.present?
      entry[:added] = added if added.present?

      Utils::SecurityLog.produce(
        organization: organization,
        log_type: "user",
        log_event: "user.role_edited",
        resources: {
          email: membership.user.email,
          roles: entry
        }
      )
    end

    def organization
      @organization ||= membership.organization
    end

    def new_roles
      @new_roles ||= Role.with_code(*params[:roles]).with_organization(membership.organization_id)
    end

    def old_roles
      @old_roles ||= membership.roles
    end

    def acting_membership
      @acting_membership ||= organization.memberships.active.find_by(user:)
    end

    def granting_admin_without_being_admin?
      new_roles.any?(&:admin?) && !acting_membership&.admin?
    end

    def last_admin_demotion?
      membership.admin? && new_roles.none?(&:admin?) && organization.admin_membership_roles.count == 1
    end
  end
end
