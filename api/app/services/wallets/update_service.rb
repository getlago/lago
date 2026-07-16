# frozen_string_literal: true

module Wallets
  class UpdateService < BaseService
    Result = BaseResult[:wallet, :billable_metrics, :billable_metric_identifiers, :payment_method]

    def initialize(wallet:, params:, partial_metadata: false)
      @wallet = wallet
      @params = params
      @partial_metadata = partial_metadata

      super
    end

    activity_loggable(
      action: "wallet.updated",
      record: -> { wallet }
    )

    def call
      return result.not_found_failure!(resource: "wallet") unless wallet
      return result unless valid_expiration_at?(expiration_at: params[:expiration_at])
      return result unless valid_recurring_transaction_rules?
      return result unless valid_limitations?
      return result unless valid_payment_method?

      if organization_flag_enabled?(:multi_entity_billing) && billing_entity_param_sent?
        if billing_entity_value_provided? && billing_entity.nil?
          return result.not_found_failure!(resource: "billing_entity")
        end

        wallet.billing_entity = billing_entity
      end

      ActiveRecord::Base.transaction do
        wallet.name = params[:name] if params.key?(:name)
        wallet.code = params[:code] if params[:code]
        wallet.priority = params[:priority] if params[:priority]
        wallet.expiration_at = params[:expiration_at] if params.key?(:expiration_at)
        unless params[:invoice_requires_successful_payment].nil?
          wallet.invoice_requires_successful_payment = ActiveModel::Type::Boolean.new.cast(params[:invoice_requires_successful_payment])
        end
        wallet.paid_top_up_min_amount_cents = params[:paid_top_up_min_amount_cents] if params.key?(:paid_top_up_min_amount_cents)
        wallet.paid_top_up_max_amount_cents = params[:paid_top_up_max_amount_cents] if params.key?(:paid_top_up_max_amount_cents)
        if params[:recurring_transaction_rules] && License.premium?
          Wallets::RecurringTransactionRules::UpdateService.call!(wallet:, params: params[:recurring_transaction_rules])
        end

        wallet.recurring_transaction_rules.find_each { |rule| validate_rule!(rule:) }

        if params.key?(:applies_to)
          wallet.allowed_fee_types = params[:applies_to][:fee_types] if params[:applies_to].key?(:fee_types)
        end

        if params.key?(:payment_method)
          wallet.payment_method_type = params[:payment_method][:payment_method_type] if params[:payment_method].key?(:payment_method_type)
          wallet.payment_method_id = params[:payment_method][:payment_method_id] if params[:payment_method].key?(:payment_method_id)
        end

        process_billable_metrics

        wallet.save!

        update_metadata!

        if needs_refresh?
          wallet.customer.flag_wallets_for_refresh
          Customers::RefreshWalletJob.perform_after_commit(wallet.customer)
        end

        InvoiceCustomSections::AttachToResourceService.call!(resource: wallet, params:)
        SendWebhookJob.perform_after_commit("wallet.updated", wallet)
      end

      result.wallet = wallet
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :wallet, :params, :partial_metadata

    def validate_rule!(rule:)
      return unless rule.fixed?

      credit_amount = rule.paid_credits
      return if credit_amount.nil? || credit_amount.zero?

      validator = Validators::WalletTransactionAmountLimitsValidator.new(
        result,
        wallet:,
        credits_amount: credit_amount.to_s,
        ignore_validation: rule.ignore_paid_top_up_limits
      )

      unless validator.valid?
        result.single_validation_failure!(field: :recurring_transaction_rules, error_code: "invalid_recurring_rule")
        result.raise_if_error!
      end
    end

    def valid_recurring_transaction_rules?
      Wallets::ValidateRecurringTransactionRulesService.new(result, **params).valid?
    end

    def valid_expiration_at?(expiration_at:)
      return true if Validators::ExpirationDateValidator.valid?(expiration_at)

      result.single_validation_failure!(field: :expiration_at, error_code: "invalid_date")
      false
    end

    def valid_limitations?
      result.billable_metrics = billable_metrics
      result.billable_metric_identifiers = billable_metric_identifiers
      Wallets::ValidateLimitationsService.new(result, **params).valid?
    end

    def valid_payment_method?
      result.payment_method = payment_method
      PaymentMethods::ValidateService.new(result, **params).valid?
    end

    def process_billable_metrics
      # In case of adding new type of limitation in wallet_targets, query from below should use compact to avoid nil values in the array
      existing_wallet_billable_metric_ids = wallet.wallet_targets.pluck(:billable_metric_id)

      billable_metrics.each do |bm|
        next if existing_wallet_billable_metric_ids.include?(bm.id)

        WalletTarget.create!(wallet:, billable_metric: bm, organization_id: wallet.organization_id)
        @wallet_targets_changed = true
      end

      sanitize_wallet_billable_metrics(existing_wallet_billable_metric_ids) if existing_wallet_billable_metric_ids.present?
    end

    def sanitize_wallet_billable_metrics(existing_wallet_billable_metric_ids)
      not_needed_wallet_target_ids = existing_wallet_billable_metric_ids - billable_metrics.pluck(:id)
      not_needed_wallet_target_ids.each do |wallet_billable_metric_id|
        target = WalletTarget.find_by(wallet:, billable_metric_id: wallet_billable_metric_id, organization: wallet.organization)
        next unless target

        target.destroy!
        @wallet_targets_changed = true
      end
    end

    def needs_refresh?
      return true if @wallet_targets_changed

      (wallet.saved_changes.keys & Wallet::REFRESH_RELEVANT_ATTRIBUTES).any?
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
        BillableMetric.where(code: billable_metric_identifiers, organization_id: wallet.organization_id)
      else
        BillableMetric.where(id: billable_metric_identifiers, organization_id: wallet.organization_id)
      end
    end

    def payment_method
      return @payment_method if defined? @payment_method
      return nil if params[:payment_method].blank? || params[:payment_method][:payment_method_id].blank?

      @payment_method = PaymentMethod.find_by(id: params[:payment_method][:payment_method_id], organization_id: wallet.organization_id)
    end

    def update_metadata!
      return unless params.key?(:metadata)

      Metadata::UpdateItemService.call!(owner: wallet, value: params[:metadata], partial: partial_metadata.present?)
    end

    def organization_flag_enabled?(flag)
      wallet.customer.organization.feature_flag_enabled?(flag)
    end

    def billing_entity_param_sent?
      params.key?(:billing_entity_id) || params.key?(:billing_entity_code)
    end

    def billing_entity_value_provided?
      params[:billing_entity_id].present? || params[:billing_entity_code].present?
    end

    def billing_entity
      return @billing_entity if defined? @billing_entity

      scope = wallet.customer.organization.billing_entities
      @billing_entity = if params[:billing_entity_id].present?
        scope.find_by(id: params[:billing_entity_id])
      elsif params[:billing_entity_code].present?
        scope.find_by(code: params[:billing_entity_code])
      end
    end
  end
end
