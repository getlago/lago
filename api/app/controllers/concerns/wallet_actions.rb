# frozen_string_literal: true

module WalletActions
  include Pagination
  extend ActiveSupport::Concern

  def wallet_create(customer)
    result = ::Wallets::CreateService.call(
      params: input_params
        .merge(organization_id: current_organization.id)
        .merge(customer:).to_h.deep_symbolize_keys
    )

    if result.success?
      render_wallet(result.wallet)
    else
      render_error_response(result)
    end
  end

  def wallet_update(wallet)
    result = ::Wallets::UpdateService.call(
      wallet:,
      params: update_params.merge(id: wallet&.id).to_h.deep_symbolize_keys
    )

    if result.success?
      render_wallet(result.wallet)
    else
      render_error_response(result)
    end
  end

  def wallet_terminate(wallet)
    result = ::Wallets::TerminateService.call(wallet:)

    if result.success?
      render_wallet(result.wallet)
    else
      render_error_response(result)
    end
  end

  def wallet_show(wallet)
    return not_found_error(resource: "wallet") unless wallet

    render_wallet(wallet)
  end

  def wallet_index(external_customer_id:, currency:, billing_entity_codes: nil)
    if billing_entity_codes.present?
      billing_entities = current_organization.all_billing_entities.where(code: billing_entity_codes)
      return not_found_error(resource: "billing_entity") if billing_entities.count != billing_entity_codes.uniq.count
    end

    result = WalletsQuery.call(
      organization: current_organization,
      pagination: {
        page: params[:page],
        limit: params[:per_page] || PER_PAGE
      },
      filters: {
        external_customer_id: external_customer_id,
        currency:,
        billing_entity_ids: billing_entities&.ids
      }.compact
    )

    if result.success?
      render(
        json: ::CollectionSerializer.new(
          result.wallets.includes(
            :billing_entity,
            :metadata,
            :billable_metrics,
            {customer: :billing_entity},
            {applied_invoice_custom_sections: :invoice_custom_section},
            {recurring_transaction_rules: {applied_invoice_custom_sections: :invoice_custom_section}}
          ),
          ::V1::WalletSerializer,
          collection_name: "wallets",
          meta: pagination_metadata(result.wallets),
          includes: %i[recurring_transaction_rules limitations applied_invoice_custom_sections]
        )
      )
    else
      render_error_response(result)
    end
  end

  private

  def input_params
    params.require(:wallet).permit(
      :rate_amount,
      :name,
      :code,
      :priority,
      :currency,
      :paid_credits,
      :granted_credits,
      :expiration_at,
      :invoice_requires_successful_payment,
      :paid_top_up_min_amount_cents,
      :paid_top_up_max_amount_cents,
      :ignore_paid_top_up_limits_on_creation,
      :transaction_name,
      :transaction_priority,
      :billing_entity_code,
      :billing_entity_id,
      metadata: {},
      transaction_metadata: [
        :key,
        :value
      ],
      recurring_transaction_rules: [
        :granted_credits,
        :grants_target_top_up,
        :interval,
        :method,
        :paid_credits,
        :started_at,
        :expiration_at,
        :target_ongoing_balance,
        :threshold_credits,
        :trigger,
        :invoice_requires_successful_payment,
        :ignore_paid_top_up_limits,
        :transaction_name,
        invoice_custom_section: [
          :skip_invoice_custom_sections,
          {invoice_custom_section_codes: []}
        ],
        transaction_metadata: [
          :key,
          :value
        ],
        payment_method: [
          :payment_method_type,
          :payment_method_id
        ]
      ],
      applies_to: [
        fee_types: [],
        billable_metric_codes: []
      ],
      invoice_custom_section: [
        :skip_invoice_custom_sections,
        {invoice_custom_section_codes: []}
      ],
      payment_method: [
        :payment_method_type,
        :payment_method_id
      ]
    )
  end

  def update_params
    params.require(:wallet).permit(
      :name,
      :code,
      :priority,
      :expiration_at,
      :invoice_requires_successful_payment,
      :paid_top_up_min_amount_cents,
      :paid_top_up_max_amount_cents,
      :billing_entity_code,
      metadata: {},
      recurring_transaction_rules: [
        :lago_id,
        :interval,
        :method,
        :started_at,
        :expiration_at,
        :target_ongoing_balance,
        :threshold_credits,
        :trigger,
        :paid_credits,
        :granted_credits,
        :grants_target_top_up,
        :invoice_requires_successful_payment,
        :ignore_paid_top_up_limits,
        :transaction_name,
        invoice_custom_section: [
          :skip_invoice_custom_sections,
          {invoice_custom_section_codes: []}
        ],
        transaction_metadata: [
          :key,
          :value
        ],
        payment_method: [
          :payment_method_type,
          :payment_method_id
        ]
      ],
      applies_to: [
        fee_types: [],
        billable_metric_codes: []
      ],
      invoice_custom_section: [
        :skip_invoice_custom_sections,
        {invoice_custom_section_codes: []}
      ],
      payment_method: [
        :payment_method_type,
        :payment_method_id
      ]
    )
  end

  def render_wallet(wallet)
    render(
      json: ::V1::WalletSerializer.new(
        wallet,
        root_name: "wallet",
        includes: %i[recurring_transaction_rules limitations applied_invoice_custom_sections]
      )
    )
  end
end
