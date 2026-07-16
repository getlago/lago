# frozen_string_literal: true

module Types
  module QuoteVersions
    class VoidReasonEnum < Types::BaseEnum
      QuoteVersion::VOID_REASONS.each_key do |reason|
        value reason
      end
    end
  end
end
