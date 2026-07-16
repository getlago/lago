# frozen_string_literal: true

module CreditNoteIndex
  include Pagination
  extend ActiveSupport::Concern

  def credit_note_index(external_customer_id:)
    billing_entities = current_organization.billing_entities.where(code: params[:billing_entity_codes]) if params[:billing_entity_codes].present?
    return not_found_error(resource: "billing_entity") if params[:billing_entity_codes].present? && billing_entities.count != params[:billing_entity_codes].count

    includes = [
      :applied_taxes,
      :error_details,
      :metadata,
      invoice: :billing_entity,
      file_attachment: :blob,
      xml_file_attachment: :blob,
      items: {
        fee: [
          :charge_filter,
          :charge,
          :billable_metric,
          :invoice,
          :pricing_unit_usage,
          :true_up_fee,
          {subscription: :plan},
          :customer
        ]
      },
      customer: [:billing_entity, :metadata, :stripe_customer, :gocardless_customer, :cashfree_customer, :adyen_customer, :moneyhash_customer, :integration_customers]
    ]

    result = CreditNotesQuery.call(
      organization: current_organization,
      includes: includes,
      pagination: {
        page: params[:page],
        limit: params[:per_page] || PER_PAGE
      },
      search_term: params[:search_term],
      filters: {
        customer_external_id: external_customer_id,
        amount_from: params[:amount_from],
        amount_to: params[:amount_to],
        billing_entity_ids: billing_entities&.ids,
        credit_status: params[:credit_status],
        currency: params[:currency],
        invoice_number: params[:invoice_number],
        issuing_date_from: (Date.iso8601(params[:issuing_date_from]) if valid_date?(params[:issuing_date_from])),
        issuing_date_to: (Date.iso8601(params[:issuing_date_to]) if valid_date?(params[:issuing_date_to])),
        reason: params[:reason],
        refund_status: params[:refund_status],
        self_billed: params[:self_billed],
        types: params[:types]
      }
    )

    if result.success?
      render(
        json: ::CollectionSerializer.new(
          result.credit_notes,
          ::V1::CreditNoteSerializer,
          collection_name: "credit_notes",
          meta: pagination_metadata(result.credit_notes),
          includes: [:items, :applied_taxes, :error_details, {customer: [:integration_customers]}]
        )
      )
    else
      render_error_response(result)
    end
  end
end
