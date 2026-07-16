# frozen_string_literal: true

module Types
  module DataApi
    module RevenueStreams
      class OrderByEnum < Types::BaseEnum
        value :gross_revenue_amount_cents
        value :net_revenue_amount_cents
      end
    end
  end
end
