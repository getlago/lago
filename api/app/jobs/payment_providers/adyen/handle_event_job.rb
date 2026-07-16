# frozen_string_literal: true

module PaymentProviders
  module Adyen
    class HandleEventJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      def perform(organization:, event_json:)
        PaymentProviders::Adyen::HandleEventService.call!(organization:, event_json:)
      end
    end
  end
end
