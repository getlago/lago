# frozen_string_literal: true

module Types
  class ObfuscatedStringType < GraphQL::Schema::Scalar
    def self.coerce_result(value, _ctx)
      return nil unless value

      "#{"•" * 8}…#{value.to_s[-3..]}"
    end
  end
end
