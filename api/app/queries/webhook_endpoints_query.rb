# frozen_string_literal: true

class WebhookEndpointsQuery < BaseQuery
  Result = BaseResult[:webhook_endpoints]

  def call
    webhook_endpoints = base_scope.result
    webhook_endpoints = paginate(webhook_endpoints)
    webhook_endpoints = apply_consistent_ordering(
      webhook_endpoints,
      default_order: {webhook_url: :asc, created_at: :desc}
    )

    result.webhook_endpoints = webhook_endpoints
    result
  end

  private

  def base_scope
    WebhookEndpoint.where(organization:).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {webhook_url_cont: search_term, m: "or"}
  end
end
