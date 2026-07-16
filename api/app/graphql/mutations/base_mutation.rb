# frozen_string_literal: true

# Mutations::BaseMutation Mutation
module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    include ExecutionErrorResponder
    include CanRequirePermissions

    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject
  end
end
