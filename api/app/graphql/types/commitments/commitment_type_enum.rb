# frozen_string_literal: true

module Types
  module Commitments
    class CommitmentTypeEnum < Types::BaseEnum
      Commitment::COMMITMENT_TYPES.keys.each do |type|
        value type
      end
    end
  end
end
