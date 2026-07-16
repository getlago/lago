# frozen_string_literal: true

module Types
  class BaseObject < GraphQL::Schema::Object
    edge_type_class(Types::BaseEdge)
    connection_type_class(Types::BaseConnection)
    field_class Types::BaseField

    # Defines a field method that batches the named ActiveRecord associations
    # through `Sources::ActiveRecordAssociation`, preventing N+1 queries when
    # the same association is requested for several parent records in a single
    # GraphQL query.
    #
    # Usage:
    #   dataload_association :customer, :organization, :subscription
    def self.dataload_association(*names)
      names.each do |name|
        define_method(name) do
          dataloader.with(Sources::ActiveRecordAssociation, name).load(object)
        end
      end
    end
  end
end
