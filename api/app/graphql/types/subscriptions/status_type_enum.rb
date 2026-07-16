# frozen_string_literal: true

module Types
  module Subscriptions
    class StatusTypeEnum < Types::BaseEnum
      Subscription::STATUSES.each do |type|
        value type
      end
    end
  end
end
