# frozen_string_literal: true

module PasswordResets
  class ResetService < BaseService
    Result = BaseResult

    def initialize(token:, new_password:)
      @token = token
      @new_password = new_password

      super
    end

    def call
      if new_password.blank?
        return result.single_validation_failure!(field: :new_password, error_code: "missing_password")
      end
      return result.single_validation_failure!(field: :token, error_code: "missing_token") if token.blank?

      password_reset = PasswordReset.where("expire_at > ?", Time.current).find_by(token:)
      return result.not_found_failure!(resource: "password_reset") if password_reset.blank?

      user = password_reset.user

      result = ActiveRecord::Base.transaction do
        user.password = new_password
        user.save!

        UsersService
          .new
          .login(user.email, new_password)
          .tap { password_reset.destroy! }
      end

      register_security_log(user)
      result
    end

    private

    attr_reader :token, :new_password

    def register_security_log(user)
      user.memberships.active.each do |membership|
        Utils::SecurityLog.produce(
          organization: membership.organization,
          log_type: "user",
          log_event: "user.password_edited",
          user: user,
          resources: {email: user.email}
        )
      end
    end
  end
end
