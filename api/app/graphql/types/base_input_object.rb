# frozen_string_literal: true

module Types
  class BaseInputObject < GraphQL::Schema::InputObject
    argument_class Types::BaseArgument

    # NOTE: This is how you can remove fields from the input object based on permissions
    def initialize(arguments, ruby_kwargs:, context:, defaults_used:)
      cleaned_arguments = arguments.argument_values.dup
      cleaned_kwargs = ruby_kwargs.dup

      self.class.arguments(context).each_value do |arg_defn|
        next if arg_defn.try(:permissions).blank?

        if arg_defn.permissions.none? { |p| context.dig(:permissions, p) }
          cleaned_arguments.delete(arg_defn.keyword)
          cleaned_kwargs.delete(arg_defn.keyword)
        end
      end

      super(cleaned_arguments, ruby_kwargs: cleaned_kwargs, context:, defaults_used:)
    end
  end
end
