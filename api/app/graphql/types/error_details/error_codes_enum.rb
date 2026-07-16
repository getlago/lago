# frozen_string_literal: true

module Types
  module ErrorDetails
    class ErrorCodesEnum < Types::BaseEnum
      ErrorDetail::ERROR_CODES.keys.each do |code|
        value code
      end
    end
  end
end
