# frozen_string_literal: true

module Types
  module Metadata
    class Input < Types::BaseInputObject
      graphql_name "MetadataInput"
      description "Input for metadata key-value pair"

      argument :key, String, required: true
      argument :value, String, required: :nullable

      ARGUMENT_OPTIONS = {
        prepare: ->(value, _ctx) { value&.reduce({}) { |h, item| h.merge(item[:key] => item[:value]) } },
        validates: {::Validators::UniqueByFieldValidator => {field_name: :key}}
      }.freeze
    end
  end
end
