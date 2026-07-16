# frozen_string_literal: true

module Roles
  class CreateService < BaseService
    Result = BaseResult[:role]

    def initialize(organization:, code:, name:, permissions:, description: nil)
      @organization = organization
      @code = code
      @name = name
      @description = description
      @permissions = permissions
      super
    end

    def call
      return result.forbidden_failure! unless License.premium?
      return result.forbidden_failure!(code: "premium_integration_missing") unless organization.custom_roles_enabled?

      role = organization.roles.create!(
        code:,
        name:,
        description:,
        permissions:
      )

      register_security_log(role)

      result.role = role
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :code, :name, :description, :permissions

    def register_security_log(role)
      Utils::SecurityLog.produce(
        organization: organization,
        log_type: "role",
        log_event: "role.created",
        resources: {role_code: role.code, permissions: role.permissions}
      )
    end
  end
end
