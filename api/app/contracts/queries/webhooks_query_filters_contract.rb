# frozen_string_literal: true

module Queries
  class WebhooksQueryFiltersContract < Dry::Validation::Contract
    # HTTP status filter accepts:
    # * individual status codes (e.g., "200", "404")
    # * wildcards (e.g., "5xx")
    # * ranges (e.g., "200-204")
    # * "timeout" word (special case for empty http statuses)
    HTTP_STATUS_REGEX = /\A(\d{3}|\dxx|\d{3}\s*-\s*\d{3}|timeout)\z/i

    params do
      required(:webhook_endpoint_id).filled(:string)

      optional(:statuses).maybe do
        array(:string, included_in?: Webhook::STATUS.map(&:to_s))
      end

      optional(:event_types).maybe do
        array(:string, included_in?: WebhookEndpoint::WEBHOOK_EVENT_TYPES)
      end

      optional(:http_statuses).maybe(:array) do
        each(:string, format?: HTTP_STATUS_REGEX)
      end

      optional(:from_date).maybe(:time)

      optional(:to_date).maybe(:time)
    end
  end
end
