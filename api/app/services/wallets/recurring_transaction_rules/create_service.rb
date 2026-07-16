# frozen_string_literal: true

module Wallets
  module RecurringTransactionRules
    class CreateService < BaseService
      Result = BaseResult[:recurring_transaction_rule, :payment_method]

      def initialize(wallet:, wallet_params:)
        @wallet = wallet
        @wallet_params = wallet_params

        super
      end

      def call
        return unless License.premium?
        return result unless valid_payment_method?

        if method == "fixed" && rule_params[:paid_credits].nil? && rule_params[:granted_credits].nil?
          paid_credits = wallet_params[:paid_credits]
          granted_credits = wallet_params[:granted_credits]
        end

        attributes = {
          organization_id: wallet.organization_id,
          paid_credits: rule_params[:paid_credits] || paid_credits || 0.0,
          granted_credits: rule_params[:granted_credits] || granted_credits || 0.0,
          threshold_credits: rule_params[:threshold_credits] || 0.0,
          interval: rule_params[:interval],
          method:,
          started_at: rule_params[:started_at],
          expiration_at: rule_params[:expiration_at],
          target_ongoing_balance: rule_params[:target_ongoing_balance],
          trigger: rule_params[:trigger].to_s,
          transaction_metadata: rule_params[:transaction_metadata] || [],
          transaction_name: rule_params[:transaction_name].presence
        }

        if rule_params.key? :ignore_paid_top_up_limits
          attributes[:ignore_paid_top_up_limits] = ActiveModel::Type::Boolean.new.cast(rule_params[:ignore_paid_top_up_limits])
        end

        attributes[:grants_target_top_up] = if method == "target"
          ActiveModel::Type::Boolean.new.cast(rule_params[:grants_target_top_up]) == true
        end

        if rule_params.key?(:payment_method)
          attributes[:payment_method_type] = rule_params[:payment_method][:payment_method_type] if rule_params[:payment_method].key?(:payment_method_type)
          attributes[:payment_method_id] = rule_params[:payment_method][:payment_method_id] if rule_params[:payment_method].key?(:payment_method_id)
        end

        attributes[:invoice_requires_successful_payment] = if rule_params.key?(:invoice_requires_successful_payment)
          ActiveModel::Type::Boolean.new.cast(rule_params[:invoice_requires_successful_payment])
        else
          wallet.invoice_requires_successful_payment?
        end

        validate_paid_credits!(
          credits_amount: attributes[:paid_credits],
          ignore_validation: attributes[:ignore_paid_top_up_limits]
        )

        rule = wallet.recurring_transaction_rules.create!(attributes)

        if rule_params.key? :invoice_custom_section
          InvoiceCustomSections::AttachToResourceService.call(resource: rule, params: rule_params)
        end

        result.recurring_transaction_rule = rule
        result
      rescue BaseService::FailedResult
        result
      end

      private

      attr_reader :wallet, :wallet_params

      def rule_params
        @rule_params ||= wallet_params[:recurring_transaction_rules].first
      end

      def method
        @method ||= rule_params[:method] || "fixed"
      end

      def validate_paid_credits!(credits_amount:, ignore_validation:)
        return if method != "fixed" || BigDecimal(credits_amount).floor(5).zero?

        validator = Validators::WalletTransactionAmountLimitsValidator.new(
          result,
          wallet:,
          credits_amount:,
          ignore_validation:
        )

        unless validator.valid?
          result.single_validation_failure!(field: :recurring_transaction_rules, error_code: "invalid_recurring_rule")
          result.raise_if_error!
        end
      end

      def valid_payment_method?
        result.payment_method = payment_method

        PaymentMethods::ValidateService.new(result, **rule_params).valid?
      end

      def payment_method
        return @payment_method if defined? @payment_method
        return nil if rule_params[:payment_method].blank? || rule_params[:payment_method][:payment_method_id].blank?

        @payment_method = PaymentMethod.find_by(id: rule_params[:payment_method][:payment_method_id], organization_id: wallet.organization_id)
      end
    end
  end
end
