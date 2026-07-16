# frozen_string_literal: true

module Webhooks
  class SendHttpService < ::BaseService
    Result = BaseResult

    def initialize(webhook:)
      @webhook = webhook

      super
    end

    def call
      webhook.endpoint = webhook.webhook_endpoint.webhook_url

      response = http_client.post_with_response(webhook.payload, webhook.generate_headers)

      mark_webhook_as_succeeded(response)

      result
    rescue LagoHttpClient::HttpError,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::HTTPBadResponse,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::EPIPE,
      Errno::EHOSTUNREACH,
      OpenSSL::SSL::SSLError,
      SocketError,
      EOFError => e

      retrying = ((webhook.retries + 1) < retry_limit)
      mark_webhook_as_unsuccessful(error: e, retrying:)
      SendHttpWebhookJob.set(wait: wait_value).perform_later(webhook) if retrying

      result
    end

    private

    attr_reader :webhook

    def http_client
      @http_client ||= LagoHttpClient::Client.new(
        webhook.webhook_endpoint.webhook_url,
        read_timeout: timeout_seconds,
        write_timeout: timeout_seconds,
        open_timeout: timeout_seconds
      )
    end

    def timeout_seconds
      ENV.fetch("LAGO_WEBHOOK_TIMEOUT_SECONDS", 30).to_i
    end

    def retry_limit
      ENV.fetch("LAGO_WEBHOOK_ATTEMPTS", 3).to_i
    end

    def mark_webhook_as_succeeded(response)
      webhook.http_status = response&.code&.to_i
      webhook.store_response(response&.body.presence || {})
      webhook.status = :succeeded
      webhook.save!
    end

    def mark_webhook_as_unsuccessful(error:, retrying:)
      if error.is_a?(LagoHttpClient::HttpError)
        webhook.http_status = error.error_code
        webhook.store_response(error.error_body)
      else
        webhook.store_response(error.message)
      end
      webhook.retries += 1
      webhook.last_retried_at = Time.zone.now
      webhook.status = retrying ? :retrying : :failed
      webhook.save!
    end

    def wait_value
      # NOTE: This is based on the Rails Active Job wait algorithm
      executions = webhook.retries
      ((executions**4) + (Kernel.rand * (executions**4) * 0.15)) + 2
    end
  end
end
