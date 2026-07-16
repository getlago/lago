# frozen_string_literal: true

module Invoices
  class PreviewService < BaseService
    Result = BaseResult[:subscriptions, :invoice, :fees_taxes]

    def initialize(customer:, subscriptions:, applied_coupons: [])
      @customer = customer
      @subscriptions = subscriptions
      @applied_coupons = applied_coupons
      @first_subscription = subscriptions.first
      @persisted_subscriptions = subscriptions.any?(&:persisted?)
      @subscription_context = fetch_context

      super
    end

    def call
      return result.forbidden_failure! unless License.premium?
      return result.not_found_failure!(resource: "customer") unless customer
      return result.not_found_failure!(resource: "subscription") if subscriptions.empty?
      return result.not_allowed_failure!(code: "premium_integration_missing") if persisted_subscriptions && !organization.preview_enabled?
      return result unless currencies_aligned?
      return result unless billing_times_aligned?
      return result unless billing_entities_aligned?

      @invoice = Invoice.new(
        organization:,
        billing_entity:,
        customer:,
        invoice_type: :subscription,
        currency: first_subscription.plan.amount_currency,
        timezone: customer.applicable_timezone,
        issuing_date:,
        payment_due_date:,
        net_payment_term: customer.applicable_net_payment_term,
        created_at: Time.current,
        updated_at: Time.current
      )
      invoice.credits = []
      invoice.subscriptions = subscriptions
      invoice.fees = []

      subscriptions.each do |subscription|
        sub_boundaries = boundaries(subscription)
        add_subscription_fee(subscription, sub_boundaries)
        add_charge_fees(subscription, sub_boundaries)
        add_fixed_charge_fees(subscription, sub_boundaries)
        add_commitment_fee(subscription, sub_boundaries)
      end

      compute_tax_and_totals

      result.invoice = invoice
      result.subscriptions = subscriptions
      result
    end

    private

    attr_accessor :customer, :subscriptions, :invoice, :applied_coupons, :first_subscription, :persisted_subscriptions, :subscription_context
    delegate :organization, to: :customer

    def billing_entity
      @billing_entity ||= if multi_entity_billing_enabled?
        first_subscription.billing_entity || customer.billing_entity
      else
        customer.billing_entity
      end
    end

    def billing_entities_aligned?
      return true unless multi_entity_billing_enabled?
      return true if subscriptions.size <= 1

      effective_entity_ids = subscriptions.map { |s| s.billing_entity_id || customer.billing_entity_id }.uniq

      if effective_entity_ids.size > 1
        result.single_validation_failure!(error_code: "subscription_billing_entities_do_not_match")
        return false
      end

      true
    end

    def multi_entity_billing_enabled?
      organization.feature_flag_enabled?(:multi_entity_billing)
    end

    def fetch_context
      return :terminated if subscriptions.any?(&:terminated?)

      :default
    end

    def currencies_aligned?
      subscription_currencies = subscriptions.filter_map { |s| s.plan&.amount_currency }

      if subscription_currencies.uniq.count > 1
        result.single_validation_failure!(error_code: "subscription_currencies_does_not_match")
        return false
      end

      if customer.currency && customer.currency != subscription_currencies.first
        unless organization.feature_flag_enabled?(:multi_currency)
          result.single_validation_failure!(error_code: "customer_currency_does_not_match")
          return false
        end
      end

      true
    end

    def billing_times_aligned?
      return true if subscriptions.size == 1

      if end_of_periods.map { |e| e.to_date.to_s }.uniq.count > 1
        result.single_validation_failure!(error_code: "billing_periods_does_not_match")
        return false
      end

      true
    end

    def end_of_periods
      @end_of_periods ||= subscriptions.map do |subscription|
        Subscriptions::DatesService
          .new_instance(subscription, Time.current, current_usage: true)
          .end_of_period
      end
    end

    def boundaries(subscription)
      date_service = Subscriptions::DatesService.new_instance(
        subscription,
        billing_time,
        current_usage: subscription.persisted? && subscription.terminated? && subscription.upgraded?
      )

      boundaries = BillingPeriodBoundaries.new(
        from_datetime: date_service.from_datetime,
        to_datetime: date_service.to_datetime,
        charges_from_datetime: date_service.charges_from_datetime,
        charges_to_datetime: date_service.charges_to_datetime,
        fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
        fixed_charges_to_datetime: date_service.fixed_charges_to_datetime,
        fixed_charges_duration: date_service.fixed_charges_duration_in_days,
        timestamp: billing_time,
        charges_duration: date_service.charges_duration_in_days
      )

      subscription.adjusted_boundaries(billing_time, boundaries)
    end

    def billing_time
      return @billing_time if defined? @billing_time

      @billing_time = if subscription_context == :terminated
        first_subscription.terminated_at
      elsif persisted_subscriptions
        end_of_periods.first + 1.day
      elsif first_subscription.plan.pay_in_advance?
        first_subscription.subscription_at
      else
        ds = Subscriptions::DatesService.new_instance(first_subscription, first_subscription.subscription_at, current_usage: true)
        ds.end_of_period + 1.day
      end
    end

    def issuing_date
      return @issuing_date if defined?(@issuing_date)

      terminated = subscription_context == :terminated
      recurring = !terminated && (first_subscription.persisted? || !first_subscription.plan.pay_in_advance?)

      date = billing_time.in_time_zone(customer.applicable_timezone).to_date
      issuing_date_service = Invoices::IssuingDateService.new(customer_settings: customer, recurring:)

      @issuing_date = date + issuing_date_service.issuing_date_adjustment.days
    end

    def payment_due_date
      (issuing_date + customer.applicable_net_payment_term.days).to_date
    end

    def add_subscription_fee(subscription, boundaries)
      return unless should_create_subscription_fee?(subscription)

      fee = Fees::SubscriptionService.call!(
        invoice:,
        subscription:,
        boundaries:,
        context: :preview
      ).fee
      return unless fee

      invoice.fees << fee
    end

    def add_charge_fees(subscription, boundaries)
      return unless subscription.persisted?

      charges = []
      subscription.plan.charges.joins(:billable_metric)
        .includes(:taxes, billable_metric: :organization, filters: {values: :billable_metric_filter})
        .where(invoiceable: true)
        .where
        .not(pay_in_advance: true, billable_metric: {recurring: false}).find_each do |c|
        next if should_not_create_charge_fee?(c, subscription)
        charges << c
      end

      context = OpenTelemetry::Context.current

      invoice.fees << Parallel.flat_map(charges, in_threads: ENV["LAGO_PARALLEL_THREADS_COUNT"]&.to_i || 0) do |charge|
        OpenTelemetry::Context.with_current(context) do
          ActiveRecord::Base.connection_pool.with_connection do
            cache_middleware = Subscriptions::ChargeCacheMiddleware.new(
              subscription:,
              charge:,
              to_datetime: boundaries.charges_to_datetime
            )

            Fees::ChargeService
              .call!(invoice:, charge:, subscription:, boundaries:, context: :invoice_preview, cache_middleware:)
              .fees
          end
        end
      end
    end

    def add_fixed_charge_fees(subscription, boundaries)
      return unless fixed_charge_boundaries_valid?(boundaries)

      fixed_charges = if subscription.persisted?
        subscription.fixed_charges
      else
        subscription.plan.fixed_charges.kept
      end

      fixed_charges.find_each do |fixed_charge|
        next unless should_create_fixed_charge_fee?(fixed_charge, subscription)

        fee_result = Fees::FixedChargeService.call(
          invoice:,
          fixed_charge:,
          subscription:,
          boundaries:,
          context: :invoice_preview
        )

        next unless fee_result.success? && fee_result.fee

        invoice.fees << fee_result.fee
      end
    end

    def add_commitment_fee(subscription, boundaries)
      return unless subscription.plan.minimum_commitment

      virtual_invoice_subscription = InvoiceSubscription.new(
        subscription:,
        invoice:,
        organization_id: subscription.organization_id,
        from_datetime: boundaries.from_datetime,
        to_datetime: boundaries.to_datetime,
        charges_from_datetime: boundaries.charges_from_datetime,
        charges_to_datetime: boundaries.charges_to_datetime,
        timestamp: billing_time
      )

      preview_fee_totals = invoice.fees
        .each_with_object({amount_cents: 0, precise_amount_cents: 0}) do |fee, totals|
          next unless fee.subscription_id == subscription.id

          totals[:amount_cents] += fee.amount_cents
          totals[:precise_amount_cents] += fee.precise_amount_cents
        end

      fee_result = Fees::Commitments::Minimum::CalculatePreviewFeeService.call(
        invoice_subscription: virtual_invoice_subscription,
        preview_fees_amount_cents: preview_fee_totals[:amount_cents],
        preview_fees_precise_amount_cents: preview_fee_totals[:precise_amount_cents]
      )

      return unless fee_result.success? && fee_result.fee

      invoice.fees << fee_result.fee
    end

    def compute_tax_and_totals
      invoice.fees_amount_cents = invoice.fees.sum(&:amount_cents)
      invoice.sub_total_excluding_taxes_amount_cents = invoice.fees_amount_cents

      if invoice.fees_amount_cents&.positive? && applied_coupons.present?
        Coupons::PreviewService.call(invoice:, applied_coupons:)
      end

      invoice.sub_total_excluding_taxes_amount_cents = invoice.fees_amount_cents - invoice.coupons_amount_cents

      if provider_taxation? && invoice.fees.any?
        apply_provider_taxes
      elsif invoice.fees.any?
        apply_taxes
      end

      invoice.sub_total_including_taxes_amount_cents = (
        invoice.sub_total_excluding_taxes_amount_cents + invoice.taxes_amount_cents
      )

      invoice.total_amount_cents = (
        invoice.sub_total_including_taxes_amount_cents - invoice.credit_notes_amount_cents
      )

      create_credit_note_credits
      create_applied_prepaid_credits
    end

    def create_credit_note_credits
      terminated_subscription = subscriptions.none?(&:downgraded?) ? subscriptions.find(&:terminated?) : nil
      credits = Preview::CreditsService.call!(invoice:, terminated_subscription:).credits

      invoice.credits << credits
      invoice.total_amount_cents -= credits.sum(&:amount_cents)
    end

    def create_applied_prepaid_credits
      return unless customer.persisted?
      return unless invoice.total_amount_cents&.positive?

      wallets_transactions = Credits::AllocatePrepaidCreditsByWalletsService.call!(invoice:).wallet_transactions
      amount_cents = wallets_transactions.sum { |_k, v| v }

      invoice.prepaid_credit_amount_cents += amount_cents
      invoice.total_amount_cents -= amount_cents
    end

    def apply_taxes
      invoice.fees.each do |fee|
        taxes_result = Fees::ApplyTaxesService.call(fee:)
        taxes_result.raise_if_error!
      end

      taxes_result = Invoices::ApplyTaxesService.call(invoice:)
      taxes_result.raise_if_error!
    end

    def apply_provider_taxes
      taxes_result = Integrations::Aggregator::Taxes::Invoices::CreateDraftService.call(invoice:, fees: invoice.fees)

      if taxes_result.success?
        result.fees_taxes = taxes_result.fees
        invoice.fees.each do |fee|
          fee_taxes = result.fees_taxes.find { |item| item.item_key == fee.item_key }

          res = Fees::ApplyProviderTaxesService.call(fee:, fee_taxes:)
          res.raise_if_error!
        end

        res = Invoices::ApplyProviderTaxesService.call(invoice:, provider_taxes: result.fees_taxes)
        res.raise_if_error!
      else
        apply_zero_tax
      end
    rescue BaseService::ThrottlingError, *Integrations::Aggregator::BaseService.retryable_errors
      apply_zero_tax
    end

    def apply_zero_tax
      invoice.taxes_amount_cents = 0
      invoice.taxes_rate = 0
    end

    def provider_taxation?
      customer.integration_customers.find { |ic| ic.tax_kind? }
    end

    def should_create_subscription_fee?(subscription)
      return true if subscription_context == :default

      subscription.terminated? == subscription.plan.pay_in_arrears?
    end

    def should_not_create_charge_fee?(charge, subscription)
      return false if subscription_context == :default

      if charge.pay_in_advance?
        condition = charge.billable_metric.recurring? &&
          subscription.terminated? &&
          (subscription.upgraded? || subscription.next_subscription.nil?)

        return condition
      end

      return false if charge.prorated?

      charge.billable_metric.recurring? &&
        subscription.terminated? &&
        subscription.upgraded? &&
        charge.included_in_next_subscription?(subscription)
    end

    def fixed_charge_boundaries_valid?(boundaries)
      return false if boundaries.fixed_charges_from_datetime.nil?
      return false if boundaries.fixed_charges_to_datetime.nil?

      boundaries.fixed_charges_from_datetime <= boundaries.fixed_charges_to_datetime
    end

    def should_create_fixed_charge_fee?(fixed_charge, subscription)
      return false if fixed_charge.pay_in_advance? && subscription.terminated?

      if !fixed_charge.pay_in_advance? && is_starting_subscription?(subscription)
        return false
      end

      true
    end

    def is_starting_subscription?(subscription)
      return false unless subscription.persisted?

      subscription.invoice_subscriptions.count == 1 &&
        subscription.invoice_subscriptions.order(:created_at).last.subscription_starting?
    end
  end
end
