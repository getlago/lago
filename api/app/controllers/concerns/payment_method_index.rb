# frozen_string_literal: true

module PaymentMethodIndex
  include Pagination
  extend ActiveSupport::Concern

  def payment_method_index(external_customer_id:)
    result = PaymentMethodsQuery.call(
      organization: current_organization,
      pagination: {
        page: params[:page],
        limit: params[:per_page] || PER_PAGE
      },
      filters: {
        external_customer_id:
      }
    )

    if result.success?
      render(
        json: ::CollectionSerializer.new(
          result.payment_methods.preload(:customer, :payment_provider),
          ::V1::PaymentMethodSerializer,
          collection_name: "payment_methods",
          meta: pagination_metadata(result.payment_methods)
        )
      )
    else
      render_error_response(result)
    end
  end
end
