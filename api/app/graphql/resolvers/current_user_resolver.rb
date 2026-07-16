# frozen_string_literal: true

module Resolvers
  # MeResolver resolves current user field
  class CurrentUserResolver < Resolvers::BaseResolver
    include AuthenticableApiUser

    description "Retrieves currently connected user"

    type Types::UserType, null: false

    def resolve
      context[:current_user]
    end
  end
end
