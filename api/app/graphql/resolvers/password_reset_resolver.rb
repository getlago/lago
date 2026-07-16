# frozen_string_literal: true

module Resolvers
  class PasswordResetResolver < Resolvers::BaseResolver
    description "Query a password reset by token"

    argument :token, String, required: true, description: "Uniq token of the password reset"

    type Types::ResetPasswords::Object, null: false

    def resolve(token: nil)
      password_reset = PasswordReset.where("expire_at > ?", Time.current).find_by(token:)

      return not_found_error(resource: "password_reset") unless password_reset

      password_reset
    end
  end
end
