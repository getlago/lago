# frozen_string_literal: true

module Mutations
  module Auth
    module Okta
      class Authorize < BaseMutation
        graphql_name "OktaAuthorize"

        argument :email, String, required: true
        argument :invite_token, String, required: false

        type Types::Auth::Okta::Authorize

        def resolve(email:, invite_token: nil)
          result = ::Auth::Okta::AuthorizeService.call(email:, invite_token:)
          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
