# frozen_string_literal: true

module Wallets
  class CreateService < BaseService
    Result = BaseResult[:wallet, :billable_metric_identifiers, :billable_metrics, :payment_method]

    def initialize(params:)
      @params = params
      super
    end

    activity_loggable(
      action: "wallet.created",
      record: -> { result.wallet }
    )

    def call
      result.billable_metric_identifiers = billable_metric_identifiers
      result.billable_metrics = billable_metrics
      result.payment_method = payment_method

      return result unless valid?

      code = params[:code]

      # only adjust generated code if it's taken
      if code.blank?
        code = params[:name].to_s.parameterize(separator: "_").presence || "default"
        code_taken = Wallet.where(organization_id:, customer_id: customer.id, status: "active", code: code).exists?
        code += "_#{Time.current.to_i}" if code_taken
      end

      attributes = {
        organization_id:,
        customer_id: customer.id,
        name: params[:name],
        code: code,
        rate_amount: params[:rate_amount],
        expiration_at: params[:expiration_at],
        status: :active,
        paid_top_up_min_amount_cents: params[:paid_top_up_min_amount_cents],
        paid_top_up_max_amount_cents: params[:paid_top_up_max_amount_cents],
        traceable: traceable?
      }

      attributes[:priority] = params[:priority] if params[:priority]

      if params.key?(:invoice_requires_successful_payment)
        attributes[:invoice_requires_successful_payment] = ActiveModel::Type::Boolean.new.cast(params[:invoice_requires_successful_payment]) || false
      end

      if params.key?(:applies_to)
        attributes[:allowed_fee_types] = params[:applies_to][:fee_types] if params[:applies_to].key?(:fee_types)
      end

      if params.key?(:payment_method)
        attributes[:payment_method_type] = params[:payment_method][:payment_method_type] if params[:payment_method].key?(:payment_method_type)
        attributes[:payment_method_id] = params[:payment_method][:payment_method_id] if params[:payment_method].key?(:payment_method_id)
      end

      if organization_flag_enabled?(:multi_entity_billing) && (params[:billing_entity_id].present? || params[:billing_entity_code].present?)
        return result.not_found_failure!(resource: "billing_entity") unless billing_entity

        attributes[:billing_entity_id] = billing_entity.id
      end

      wallet = Wallet.new(attributes)

      ActiveRecord::Base.transaction do
        if currency.present? && (!organization_flag_enabled?(:multi_currency) || customer.currency.blank?)
          Customers::UpdateCurrencyService.call!(customer: customer, currency:)
        end

        wallet.currency = organization_flag_enabled?(:multi_currency) ? (currency || wallet.customer.currency) : wallet.customer.currency
        wallet.save!

        validate_wallet_initial_amount! wallet

        if params[:recurring_transaction_rules].present?
          Wallets::RecurringTransactionRules::CreateService.call!(wallet:, wallet_params: params)
        end

        if params[:invoice_custom_section].present?
          InvoiceCustomSections::AttachToResourceService.call(resource: wallet, params:)
        end

        billable_metrics.each do |bm|
          WalletTarget.create!(wallet:, billable_metric: bm, organization_id:)
        end

        create_metadata(wallet, params[:metadata]) if !params[:metadata].nil?

        customer.flag_wallets_for_refresh
      end

      result.wallet = wallet

      SendWebhookJob.perform_after_commit("wallet.created", wallet)

      schedule_top_up(wallet)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :params

    def schedule_top_up(wallet)
      return unless positive_amount?(paid_credits) || positive_amount?(granted_credits)

      WalletTransactions::CreateJob.perform_after_commit(
        organization_id:,
        params: {
          wallet_id: wallet.id,
          paid_credits: paid_credits,
          granted_credits: granted_credits,
          source: :manual,
          metadata: params[:transaction_metadata],
          name: params[:transaction_name],
          priority: params[:transaction_priority],
          ignore_paid_top_up_limits: params[:ignore_paid_top_up_limits_on_creation]
        }
      )
    end

    def positive_amount?(amount)
      amount && BigDecimal(amount).positive?
    end

    def paid_credits
      params[:paid_credits]
    end

    def granted_credits
      params[:granted_credits]
    end

    def customer
      params[:customer]
    end

    def organization_id
      params[:organization_id]
    end

    def currency
      params[:currency]
    end

    def organization_flag_enabled?(flag)
      customer.organization.feature_flag_enabled?(flag)
    end

    def valid?
      Wallets::ValidateService.new(result, **params).valid?
    end

    def validate_wallet_initial_amount!(wallet)
      reject_credits_rounding_to_zero!(wallet)

      return unless positive_paid_credit_amount?

      Validators::WalletTransactionAmountLimitsValidator.new(
        result,
        wallet:,
        credits_amount: paid_credits,
        ignore_validation: params[:ignore_paid_top_up_limits_on_creation]
      ).raise_if_invalid!
    end

    def reject_credits_rounding_to_zero!(wallet)
      {paid_credits:, granted_credits:}.each do |field, credits|
        next unless WalletCredit.rounds_to_zero?(wallet:, credit_amount: credits)

        result.single_validation_failure!(error_code: "amount_rounds_to_zero", field:)
        result.raise_if_error!
      end
    end

    def positive_paid_credit_amount?
      BigDecimal(paid_credits).positive?
    rescue ArgumentError, TypeError
      false
    end

    def billable_metric_identifiers
      return [] if params[:applies_to].blank?

      key = api_context? ? :billable_metric_codes : :billable_metric_ids

      return [] if params[:applies_to][key].blank?

      params[:applies_to][key]&.compact&.uniq
    end

    def billable_metrics
      return @billable_metrics if defined?(@billable_metrics)
      return [] if billable_metric_identifiers.blank?

      @billable_metrics = if api_context?
        BillableMetric.where(code: billable_metric_identifiers, organization_id:)
      else
        BillableMetric.where(id: billable_metric_identifiers, organization_id:)
      end
    end

    def payment_method
      return @payment_method if defined? @payment_method
      return nil if params[:payment_method].blank? || params[:payment_method][:payment_method_id].blank?

      @payment_method = PaymentMethod.find_by(id: params[:payment_method][:payment_method_id], organization_id:)
    end

    def billing_entity
      return @billing_entity if defined? @billing_entity

      scope = customer.organization.billing_entities
      @billing_entity = if params[:billing_entity_id].present?
        scope.find_by(id: params[:billing_entity_id])
      elsif params[:billing_entity_code].present?
        scope.find_by(code: params[:billing_entity_code])
      end
    end

    def create_metadata(wallet, metadata_value)
      Metadata::UpdateItemService.new(
        owner: wallet,
        value: metadata_value,
        partial: false
      ).call
    end

    def traceable?
      customer.wallets.active.where(traceable: false).none?
    end
  end
end
