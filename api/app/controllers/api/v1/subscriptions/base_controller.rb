# frozen_string_literal: true

module Api
  module V1
    module Subscriptions
      class BaseController < Api::BaseController
        before_action :find_subscription

        private

        attr_reader :subscription

        def find_subscription
          @subscription = current_organization.subscriptions
            .order("terminated_at DESC NULLS FIRST, started_at DESC") # TODO: Confirm
            .find_by!(
              external_id: params[:subscription_external_id],
              # we're keeping both `subscription_status` and `status` for backward compatibility,
              # but we should rely more on the `subscription_status`
              status: params[:subscription_status] || params[:status] || :active
            )
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "subscription")
        end
      end
    end
  end
end
