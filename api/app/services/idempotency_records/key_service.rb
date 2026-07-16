# frozen_string_literal: true

module IdempotencyRecords
  class KeyService < BaseService
    Result = BaseResult[:idempotency_key]

    # WARNING: changing this value is very dangerous!
    # only do this if you really have to.
    # Uniqueness for existing values can no longer be enforced once this is changed
    KEY_VERSION = "v1"
    SEPARATOR = "|"

    def initialize(**key_parts)
      @key_parts = key_parts

      super()
    end

    def call
      string_to_digest = key_parts.sort.map { |k, v| "#{k}#{v}" }.join(SEPARATOR)
      result.idempotency_key = Digest::SHA256.digest("#{KEY_VERSION}#{SEPARATOR}#{string_to_digest}")
      result
    end

    private

    attr_reader :key_parts
  end
end
