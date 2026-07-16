# frozen_string_literal: true

module Resolvers
  class VersionResolver < Resolvers::BaseResolver
    description "Retrieve the version of the application"

    type Types::Utils::CurrentVersion, null: false

    def resolve
      LAGO_VERSION
    end
  end
end
