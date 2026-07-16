# frozen_string_literal: true

class WebhooksController < ApplicationController
  def stripe
    result = InboundWebhooks::CreateService.call(
      organization_id: params[:organization_id],
      webhook_source: :stripe,
      code: params[:code].presence,
      payload: request.body.read,
      signature: request.headers["HTTP_STRIPE_SIGNATURE"],
      event_type: params[:type]
    )

    return head(:bad_request) unless result.success?

    head(:ok)
  end

  def cashfree
    result = PaymentProviders::Cashfree::HandleIncomingWebhookService.call(
      organization_id: params[:organization_id],
      code: params[:code].presence,
      body: request.body.read,
      timestamp: request.headers["X-Cashfree-Timestamp"] || request.headers["X-Webhook-Timestamp"],
      signature: request.headers["X-Cashfree-Signature"] || request.headers["X-Webhook-Signature"]
    )

    unless result.success?
      if result.error.is_a?(BaseService::ServiceFailure) && result.error.code == "webhook_error"
        return head(:bad_request)
      end

      result.raise_if_error!
    end

    head(:ok)
  end

  def flutterwave
    result = PaymentProviders::Flutterwave::HandleIncomingWebhookService.call(
      organization_id: params[:organization_id],
      code: params[:code].presence,
      body: request.body.read,
      secret: request.headers["verif-hash"]
    )

    unless result.success?
      if result.error.is_a?(BaseService::ServiceFailure) && result.error.code == "webhook_error"
        return head(:bad_request)
      end

      result.raise_if_error!
    end

    head(:ok)
  end

  def gocardless
    result = PaymentProviders::Gocardless::HandleIncomingWebhookService.call(
      organization_id: params[:organization_id],
      code: params[:code].presence,
      body: request.body.read,
      signature: request.headers["Webhook-Signature"]
    )

    unless result.success?
      if result.error.is_a?(BaseService::ServiceFailure) && result.error.code == "webhook_error"
        return head(:bad_request)
      end

      result.raise_if_error!
    end

    head(:ok)
  end

  def adyen
    result = PaymentProviders::Adyen::HandleIncomingWebhookService.call(
      organization_id: params[:organization_id],
      code: params[:code].presence,
      body: adyen_params.to_h
    )

    unless result.success?
      return head(:bad_request) if result.error.code == "webhook_error"

      result.raise_if_error!
    end

    render(json: "[accepted]")
  end

  def adyen_params
    params["notificationItems"]&.first&.dig("NotificationRequestItem")&.permit!
  end

  def moneyhash
    result = InboundWebhooks::CreateService.call(
      organization_id: params[:organization_id],
      webhook_source: :moneyhash,
      code: params[:code].presence,
      payload: JSON.parse(request.body.read),
      signature: request.headers["MoneyHash-Signature"],
      event_type: params[:type]
    )

    return head(:bad_request) unless result.success?

    head(:ok)
  end
end
