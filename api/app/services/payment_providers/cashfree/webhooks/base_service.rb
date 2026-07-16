# frozen_string_literal: true

module PaymentProviders
  module Cashfree
    module Webhooks
      class BaseService < BaseService
        def initialize(organization_id:, event_json:)
          @organization = Organization.find(organization_id)
          @event_json = event_json

          super
        end

        private

        attr_reader :organization, :event_json

        def event
          @event ||= JSON.parse(event_json)
        end
      end
    end
  end
end
