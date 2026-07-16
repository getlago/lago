# frozen_string_literal: true

module Extensions
  class FieldAuthorizationExtension < GraphQL::Schema::FieldExtension
    def resolve(object:, arguments:, context:)
      super if field.permissions.any? { |p| context.dig(:permissions, p) }
    end
  end
end
