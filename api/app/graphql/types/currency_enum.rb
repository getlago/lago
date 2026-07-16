# frozen_string_literal: true

module Types
  class CurrencyEnum < Types::BaseEnum
    Currencies::ACCEPTED_CURRENCIES.each do |code, description|
      value code, description
    end
  end
end
