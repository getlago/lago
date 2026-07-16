# frozen_string_literal: true

module Types
  module QuoteVersions
    class StatusEnum < Types::BaseEnum
      QuoteVersion::STATUSES.each_key do |status|
        value status
      end
    end
  end
end
