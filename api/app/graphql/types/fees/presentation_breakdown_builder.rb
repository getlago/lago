# frozen_string_literal: true

module Types
  module Fees
    class PresentationBreakdownBuilder
      ALL = :all
      UNGROUPED = :ungrouped
      GROUPED = :grouped

      DISPLAY_IN_INVOICE = :display_in_invoice

      def self.call(fees, filter:, filter_breakdown:)
        new(fees, filter:, filter_breakdown:).call
      end

      def initialize(fees, filter:, filter_breakdown:)
        @fees = fees
        @filter = filter
        @filter_breakdown = filter_breakdown
      end

      def call
        Array(fees).flat_map do |fee|
          next [] if filter == UNGROUPED && fee.grouped_or_filtered?
          next [] if filter == GROUPED && fee.ungrouped_or_filtered?

          breakdowns = (filter_breakdown == DISPLAY_IN_INVOICE) ? fee.presentation_breakdowns_displayed_in_invoice : fee.presentation_breakdowns

          breakdowns.map do |breakdown|
            {
              presentation_by: breakdown.presentation_by,
              units: breakdown.units.to_s
            }
          end
        end
      end

      private

      attr_reader :fees, :filter, :filter_breakdown
    end
  end
end
