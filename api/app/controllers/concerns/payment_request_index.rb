# frozen_string_literal: true

module PaymentRequestIndex
  include Pagination
  extend ActiveSupport::Concern

  def payment_request_index(external_customer_id:)
    filters = params.permit(:payment_status, :currency, billing_entity_codes: []).to_h
    billing_entity_codes = filters.delete(:billing_entity_codes)

    if billing_entity_codes.present?
      billing_entities = current_organization.all_billing_entities.where(code: billing_entity_codes)
      return not_found_error(resource: "billing_entity") if billing_entities.count != billing_entity_codes.uniq.count

      filters[:billing_entity_ids] = billing_entities.ids
    end

    filters[:external_customer_id] = external_customer_id
    result = PaymentRequestsQuery.call(
      organization: current_organization,
      pagination: {
        page: params[:page],
        limit: params[:per_page] || PER_PAGE
      },
      filters: filters
    )

    if result.success?
      render(
        json: ::CollectionSerializer.new(
          result.payment_requests.preload(:customer, :invoices),
          ::V1::PaymentRequestSerializer,
          collection_name: "payment_requests",
          meta: pagination_metadata(result.payment_requests),
          includes: %i[customer invoices]
        )
      )
    else
      render_error_response(result)
    end
  end
end
