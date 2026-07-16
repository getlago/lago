# frozen_string_literal: true

module Types
  module DataApi
    class TimeGranularityEnum < Types::BaseEnum
      value :daily
      value :weekly
      value :monthly
    end
  end
end
