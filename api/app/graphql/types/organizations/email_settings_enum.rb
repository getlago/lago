# frozen_string_literal: true

module Types
  module Organizations
    class EmailSettingsEnum < Types::BaseEnum
      description "Organization Email Settings Values"

      Organization::EMAIL_SETTINGS.each do |value|
        value(value.tr(".", "_"), value, value:)
      end
    end
  end
end
