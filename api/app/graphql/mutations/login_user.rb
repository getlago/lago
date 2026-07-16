# frozen_string_literal: true

# Mutations::LoginUser Mutation
module Mutations
  class LoginUser < BaseMutation
    description "Opens a session for an existing user"

    argument :email, String, required: true
    argument :password, String, required: true

    type Types::Payloads::LoginUserType

    def resolve(email:, password:)
      result = UsersService.new.login(email, password)
      result.success? ? result : result_error(result)
    end
  end
end
