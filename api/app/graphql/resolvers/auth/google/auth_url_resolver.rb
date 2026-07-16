# frozen_string_literal: true

module Resolvers
  module Auth
    module Google
      class AuthUrlResolver < Resolvers::BaseResolver
        graphql_name "GoogleAuthUrl"
        description "Get Google auth url."

        type Types::Auth::Google::AuthUrl, null: false

        def resolve(**_args)
          result = ::Auth::GoogleService
            .new
            .authorize_url(context[:request])

          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
