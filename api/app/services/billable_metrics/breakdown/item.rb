# frozen_string_literal: true

module BillableMetrics
  module Breakdown
    Item = Data.define(:date, :action, :amount, :duration, :total_duration)
  end
end
