# frozen_string_literal: true

module Types
  module BillingEntities
    class EmailSettingsEnum < Types::BaseEnum
      graphql_name "BillingEntityEmailSettingsEnum"
      description "BillingEntity Email Settings Values"

      ::BillingEntity::EMAIL_SETTINGS.each do |value|
        value(value.tr(".", "_"), value, value:)
      end
    end
  end
end
