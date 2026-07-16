# frozen_string_literal: true

module Validators
  class UniqueByFieldValidator < GraphQL::Schema::Validator
    attr_reader :code_key

    def initialize(field_name: :code, **default_options)
      @code_key = field_name
      super(**default_options)
    end

    def validate(object, context, value)
      duplicates = value.map { it[code_key] }.tally.select { |_, count| count > 1 }.keys

      if duplicates.any?
        "duplicated_field"
      end
    end
  end
end
