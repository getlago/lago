# frozen_string_literal: true

module Roles
  class UpdateService < BaseService
    Result = BaseResult[:role]

    def initialize(role:, params:)
      @role = role
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "role") unless role
      return result.forbidden_failure!(code: "predefined_role") if predefined_role?

      role.update!(params.slice(:name, :description, :permissions).compact)

      register_security_log

      result.role = role
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :role, :params

    def predefined_role?
      role.organization_id.nil?
    end

    def register_security_log
      diff = role.previous_changes.slice("name", "description").to_h
        .transform_keys(&:to_sym)
        .transform_values { |v| {deleted: v[0], added: v[1]}.compact }

      if role.previous_changes.key?("permissions")
        old_perms, new_perms = role.previous_changes["permissions"]
        entry = {}
        deleted = old_perms - new_perms
        added = new_perms - old_perms
        entry[:deleted] = deleted if deleted.present?
        entry[:added] = added if added.present?
        diff[:permissions] = entry if entry.present?
      end

      Utils::SecurityLog.produce(
        organization: role.organization,
        log_type: "role",
        log_event: "role.updated",
        resources: {role_code: role.code, **diff}
      )
    end
  end
end
