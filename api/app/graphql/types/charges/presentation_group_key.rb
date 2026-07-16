# frozen_string_literal: true

module Types
  module Charges
    class PresentationGroupKey < Types::BaseObject
      field :options, Types::Charges::PresentationGroupKeyOptions, null: true
      field :value, String, null: false
    end
  end
end
