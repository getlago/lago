# frozen_string_literal: true

module Resolvers
  class BaseResolver < GraphQL::Schema::Resolver
    include ExecutionErrorResponder
    include CanRequirePermissions
  end
end
