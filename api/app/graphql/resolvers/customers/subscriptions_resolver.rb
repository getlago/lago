# frozen_string_literal: true

module Resolvers
  module Customers
    class SubscriptionsResolver < Resolvers::BaseResolver
      REQUIRED_PERMISSION = "customers:view"

      description "Query subscriptions of a customer"

      argument :status, [Types::Subscriptions::StatusTypeEnum], required: false do
        description "Statuses of subscriptions to retrieve"
      end

      type Types::Subscriptions::Object, null: false

      # FE needs possibility to fetch subscriptions by status. However if status is pending, only
      # starting_in_the_future subscriptions should be returned since FE handles downgraded (pending)
      # subscriptions a bit different (it checks if next_plan exists and it uses some of next plan's properties
      # that are needed in the UI)
      def resolve(status: nil)
        statuses = status
        subscriptions = object.subscriptions

        return subscriptions.order(created_at: :desc).reject { |s| s.pending? && s.previous_subscription&.downgraded? } if statuses.blank?

        # if requested statuses do not include pending ones we should just perform filtering by given statuses
        return subscriptions.where(status: statuses).order(created_at: :desc) unless statuses&.include?("pending")

        statuses -= ["pending"]

        # if requested status is only pending, we should return only subscriptions that are starting later
        return subscriptions.starting_in_the_future.order(created_at: :desc) if statuses.blank?

        # if requested statuses are array of pending and some other statuses, we should return pending subscriptions
        # that are starting later or other subscriptions filtered by statuses without pending one
        subscriptions.where(status: statuses).or(subscriptions.starting_in_the_future).order(created_at: :desc)
      end
    end
  end
end
