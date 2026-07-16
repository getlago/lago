# frozen_string_literal: true

module Webhooks
  class RetryService < ::BaseService
    def initialize(webhook:)
      @webhook = webhook

      super
    end

    def call
      return result.not_found_failure!(resource: "webhook") unless webhook
      return result.not_allowed_failure!(code: "is_succeeded") if webhook.succeeded?

      SendHttpWebhookJob.perform_later(webhook)

      result.webhook = webhook
      result
    end

    private

    attr_reader :webhook
  end
end
