# frozen_string_literal: true

module Mutations
  module Auth
    module Okta
      class AcceptInvite < BaseMutation
        graphql_name "OktaAcceptInvite"
        description "Accepts a membership invite with Okta Oauth"

        input_object_class Types::Auth::Okta::AcceptInviteInput

        type Types::Payloads::LoginUserType

        def resolve(code:, invite_token:, state:)
          result = ::Auth::Okta::AcceptInviteService.call(code:, invite_token:, state:)

          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
