# frozen_string_literal: true

module Invites
  class CreateService < BaseService
    Result = BaseResult[:invite, :invite_url]

    def initialize(args)
      @args = args
      super
    end

    def call
      return result.forbidden_failure!(code: "cannot_grant_admin") if granting_admin_without_being_admin?
      return result unless valid?(args)

      result.invite = Invite.create!(
        organization_id: args[:current_organization].id,
        email: args[:email],
        token: generate_token,
        roles: args[:roles]
      )

      result.invite_url = build_invite_url(result.invite.token)
      register_security_log

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :args

    def register_security_log
      Utils::SecurityLog.produce(
        organization: args[:current_organization],
        log_type: "user",
        log_event: "user.invited",
        resources: {invitee_email: result.invite.email}
      )
    end

    def generate_token
      token = SecureRandom.hex(20)

      return generate_token if Invite.exists?(token:)

      token
    end

    def valid?(args)
      Invites::ValidateService.new(result, **args).valid?
    end

    def granting_admin_without_being_admin?
      return false if args[:skip_admin_check] # NOTE: used by system-level callers that operate without a user (e.g. Admin::OrganizationsController)
      return false unless args[:roles]&.include?("admin")

      acting_membership = args[:current_organization].memberships.active.find_by(user: args[:user])
      !acting_membership&.admin?
    end

    def build_invite_url(token)
      frontend_url = ENV.fetch("LAGO_FRONT_URL", "http://localhost:3000")
      "#{frontend_url}/invitation/#{token}"
    end
  end
end
