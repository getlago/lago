# frozen_string_literal: true

module PaymentMethods
  class DetermineService < BaseService
    Result = BaseResult[:payment_method]

    def initialize(invoice:, customer:, payment_method_params:)
      @invoice = invoice
      @customer = customer
      @payment_method_params = payment_method_params

      super
    end

    def call
      result.payment_method = if payment_method_params.present?
        determine_override_payment_method
      else
        determine_invoice_payment_method
      end

      result
    end

    private

    attr_reader :invoice, :customer, :payment_method_params

    def determine_override_payment_method
      return nil if payment_method_params[:payment_method_type] == "manual"

      if payment_method_params[:payment_method_id].present?
        customer.payment_methods.find_by(id: payment_method_params[:payment_method_id])
      else
        customer.default_payment_method
      end
    end

    def determine_invoice_payment_method
      case invoice.invoice_type
      when "subscription", "advance_charges", "progressive_billing"
        determine_subscription_payment_method
      when "credit"
        determine_credit_payment_method
      else
        customer.default_payment_method
      end
    end

    def determine_subscription_payment_method
      subscription = invoice.invoice_subscriptions.first&.subscription
      return nil unless subscription

      return nil if subscription.payment_method_type == "manual"

      if subscription.payment_method_id.present?
        return customer.payment_methods.find_by(id: subscription.payment_method_id)
      end

      customer.default_payment_method
    end

    def determine_credit_payment_method
      wallet_transaction = invoice.wallet_transactions.first
      return nil unless wallet_transaction

      return nil if wallet_transaction.payment_method_type == "manual"

      if wallet_transaction.payment_method_id.present?
        return customer.payment_methods.find_by(id: wallet_transaction.payment_method_id)
      end

      if wallet_transaction.source.to_s.in?(%w[interval threshold])
        rule = wallet_transaction.wallet.recurring_transaction_rules.active.first
        return nil if rule&.payment_method_type == "manual"
        return customer.payment_methods.find_by(id: rule.payment_method_id) if rule&.payment_method_id.present?
      end

      wallet = wallet_transaction.wallet
      return nil if wallet.payment_method_type == "manual"

      if wallet.payment_method_id.present?
        return customer.payment_methods.find_by(id: wallet.payment_method_id)
      end

      customer.default_payment_method
    end
  end
end
