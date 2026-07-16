# frozen_string_literal: true

module Types
  module Integrations
    class IntegrationTypeEnum < Types::BaseEnum
      Organization::INTEGRATIONS.each do |type|
        value type
      end
    end
  end
end
