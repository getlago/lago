# frozen_string_literal: true

module Types
  module Integrations
    class PremiumIntegrationTypeEnum < Types::BaseEnum
      Organization::PREMIUM_INTEGRATIONS.each do |type|
        value type
      end
    end
  end
end
