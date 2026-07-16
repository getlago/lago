# frozen_string_literal: true

module PaymentProviders
  module Gocardless
    class HandleEventJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      unique :until_executed, on_conflict: :log

      def perform(organization: nil, payment_provider: nil, events_json: nil, event_json: nil)
        # NOTE: temporary keeps both events_json and event_json to avoid errors during the deployment
        if events_json.present?
          JSON.parse(events_json)["events"].each do |event|
            PaymentProviders::Gocardless::HandleEventJob.perform_later(payment_provider:, event_json: event.to_json)
          end

          return
        end

        PaymentProviders::Gocardless::HandleEventService.call(payment_provider:, event_json:).raise_if_error!
      end
    end
  end
end
