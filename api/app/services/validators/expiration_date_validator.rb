# frozen_string_literal: true

module Validators
  module ExpirationDateValidator
    def self.valid?(expiration_at)
      return true if expiration_at.blank?

      Utils::Datetime.valid_format?(expiration_at, format: :any) &&
        Utils::Datetime.future_date?(expiration_at)
    end
  end
end
