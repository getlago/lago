# frozen_string_literal: true

module PasswordResets
  class CreateService < BaseService
    Result = BaseResult[:id]

    def initialize(user:)
      @user = user

      super
    end

    def call
      return result.not_found_failure!(resource: "user") if user.blank?

      password_reset = PasswordReset.create!(
        user:,
        token: SecureRandom.hex(20),
        expire_at: Time.current + 30.minutes
      )

      PasswordResetMailer.with(password_reset:).requested.deliver_later
      register_security_log

      result.id = password_reset.id

      result
    end

    private

    attr_reader :user

    def register_security_log
      user.memberships.active.each do |membership|
        Utils::SecurityLog.produce(
          organization: membership.organization,
          log_type: "user",
          log_event: "user.password_reset_requested",
          user: user,
          resources: {email: user.email}
        )
      end
    end
  end
end
