# frozen_string_literal: true

module Mutations
  module Auth
    module Google
      class AcceptInvite < BaseMutation
        graphql_name "GoogleAcceptInvite"
        description "Accepts a membership invite with Google Oauth"

        argument :code, String, required: true
        argument :invite_token, String, required: true

        type Types::Payloads::RegisterUserType

        def resolve(code:, invite_token:)
          result = ::Auth::GoogleService.new.accept_invite(code, invite_token)

          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
