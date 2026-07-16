# frozen_string_literal: true

require "lago_http_client"

module Webhooks
  # NOTE: Abstract Service, should not be used directly
  class BaseService
    def initialize(object:, options: {})
      @object = object
      @options = options&.with_indifferent_access
    end

    def call
      return if current_organization.webhook_endpoints.none?

      payload = {
        :webhook_type => webhook_type,
        :object_type => object_type,
        :organization_id => current_organization.id,
        object_type => object_serializer.serialize
      }

      # TODO: Wrap in transaction so we create all webhook models or none
      #       Ensure the http jobs are dispatched after the transaction is committed
      current_organization.webhook_endpoints.each do |webhook_endpoint|
        next unless subscribed?(webhook_endpoint)

        webhook = create_webhook(webhook_endpoint, payload)
        SendHttpWebhookJob.perform_later(webhook)
      rescue ActiveRecord::InvalidForeignKey
        # The webhook endpoint was deleted while the transaction was in progress
        Rails.logger.error("SendWebhookJob failed for deleted webhook endpoint #{webhook_endpoint.id}")
        next
      end
    end

    private

    attr_reader :object, :options

    def subscribed?(webhook_endpoint)
      return true if webhook_endpoint.event_types.nil?
      webhook_endpoint.event_types.include?(webhook_type)
    end

    def object_serializer
      # Empty
    end

    def current_organization
      @current_organization ||= object.organization
    end

    def webhook_type
      # Empty
    end

    def object_type
      # Empty
    end

    def create_webhook(webhook_endpoint, payload)
      webhook = Webhook.new(webhook_endpoint:)
      webhook.organization_id = current_organization&.id
      webhook.webhook_type = webhook_type
      webhook.endpoint = webhook_endpoint.webhook_url
      # Question: When can this be a hash?
      webhook.object_id = object.is_a?(Hash) ? object.fetch(:id, nil) : object&.id
      webhook.object_type = object.is_a?(Hash) ? object.fetch(:class, nil) : object&.class&.to_s
      webhook.store_payload(payload)
      webhook.pending!
      webhook
    end
  end
end
