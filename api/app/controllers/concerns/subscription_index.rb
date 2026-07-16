# frozen_string_literal: true

module SubscriptionIndex
  include Pagination
  extend ActiveSupport::Concern

  def subscription_index(external_customer_id: nil)
    billing_entities = current_organization.all_billing_entities.where(code: params[:billing_entity_codes]) if params[:billing_entity_codes].present?
    return not_found_error(resource: "billing_entity") if params[:billing_entity_codes].present? && billing_entities.count != params[:billing_entity_codes].count

    filters = params.permit(:plan_code, :overriden, :overridden, :currency, :external_id, status: [])
    filters[:status] = ["active"] if filters[:status].blank?
    filters[:external_customer_id] = external_customer_id
    filters[:billing_entity_ids] = billing_entities&.ids
    result = SubscriptionsQuery.call(
      organization: current_organization,
      pagination: {
        page: params[:page],
        limit: params[:per_page] || PER_PAGE
      },
      filters: filters
    )

    if result.success?
      subscriptions = result.subscriptions
        .includes(:plan, :activation_rules, previous_subscription: :plan, next_subscriptions: :plan, customer: :billing_entity)

      render(
        json: ::CollectionSerializer.new(
          subscriptions,
          ::V1::SubscriptionSerializer,
          collection_name: "subscriptions",
          meta: pagination_metadata(subscriptions),
          organization: current_organization
        )
      )
    else
      render_error_response(result)
    end
  end
end
