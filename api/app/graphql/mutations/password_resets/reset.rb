# frozen_string_literal: true

module Mutations
  module PasswordResets
    class Reset < BaseMutation
      graphql_name "ResetPassword"
      description "Reset password for user and log in"

      argument :new_password, String, required: true
      argument :token, String, required: true

      type Types::Payloads::LoginUserType

      def resolve(new_password:, token:)
        result = ::PasswordResets::ResetService.call(token:, new_password:)

        result.success? ? result : result_error(result)
      end
    end
  end
end
