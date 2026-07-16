# frozen_string_literal: true

module Mutations
  module Auth
    module Google
      class RegisterUser < BaseMutation
        graphql_name "GoogleRegisterUser"
        description "Register a new user with Google Oauth"

        argument :code, String, required: true
        argument :organization_name, String, required: true

        type Types::Payloads::RegisterUserType

        def resolve(code:, organization_name:)
          result = ::Auth::GoogleService.new.register_user(code, organization_name)
          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
