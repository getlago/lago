# frozen_string_literal: true

module Types
  class BaseUnion < GraphQL::Schema::Union
    extend GraphqlPagination::CollectionType
  end
end
