# frozen_string_literal: true

# This is a reusable, model-agnostic loader for ActiveRecord associations.
#
# Prevents N+1 queries when fetching associated records across multiple objects
# in a single GraphQL query (e.g., `quotes { versions { ... } }`).
#
# Collects all requested objects and preloads the specified association
# in a single query, then maps the results back to the original objects,
# ensuring each object receives its associated records.
#
# Usage in GraphQL types:
#   dataloader.with(Sources::ActiveRecordAssociation, :versions).load(object)

module Sources
  class ActiveRecordAssociation < GraphQL::Dataloader::Source
    def initialize(association_name)
      @association_name = association_name
    end

    def fetch(records)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: @association_name
      ).call

      records.map { |record| record.public_send(@association_name) }
    end
  end
end
