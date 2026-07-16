# frozen_string_literal: true

# Mutations::Auth::Google::LoginUser Mutation
module Mutations
  module Auth
    module Google
      class LoginUser < BaseMutation
        graphql_name "GoogleLoginUser"
        description "Opens a session for an existing user with Google Oauth"

        argument :code, String, required: true

        type Types::Payloads::LoginUserType

        def resolve(code:)
          result = ::Auth::GoogleService.new.login(code)
          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
