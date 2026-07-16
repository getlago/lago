# frozen_string_literal: true

class FeeBoundariesHelper
  class BillingPeriod
    def initialize(from_datetime:, to_datetime:)
      @from_datetime = parse_datetime(from_datetime)
      @to_datetime = parse_datetime(to_datetime)
    end

    attr_reader :from_datetime, :to_datetime

    def to_grouping_key
      [from_datetime&.to_date, to_datetime&.to_date]
    end

    def ==(other)
      to_grouping_key == other.to_grouping_key
    end

    def eql?(other)
      self == other
    end

    def <=>(other)
      [from_datetime, to_datetime] <=> [other.from_datetime, other.to_datetime]
    end

    delegate :hash, to: :to_grouping_key

    def parse_datetime(value)
      return value if value.is_a?(Time) || value.is_a?(DateTime)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end
  end

  class GroupedFees
    def initialize(billing_period:, subscription_fee:, fixed_charge_fees:, charge_fees:, commitment_fee:)
      @billing_period = billing_period
      @subscription_fee = subscription_fee
      @fixed_charge_fees = fixed_charge_fees
      @charge_fees = charge_fees
      @commitment_fee = commitment_fee
    end

    attr_reader :billing_period, :subscription_fee, :fixed_charge_fees, :charge_fees, :commitment_fee

    def has_any_fees?
      subscription_fee.present? ||
        fixed_charge_fees.any? ||
        charge_fees.any? ||
        commitment_fee.present?
    end

    def has_displayable_charges?
      # Filter out true-up fees and zero-unit fees for display purposes
      charge_fees.any? { |f| f.true_up_parent_fee.nil? && f.units.positive? }
    end

    def has_displayable_fixed_charges?
      fixed_charge_fees.any? { |f| f.units.positive? }
    end
  end

  def self.billing_period_for(fee, invoice_subscription:)
    case fee.fee_type.to_sym
    when :subscription
      subscription_fee_billing_period(fee, invoice_subscription)
    when :charge
      charge_fee_billing_period(fee, invoice_subscription)
    when :fixed_charge
      fixed_charge_fee_billing_period(fee, invoice_subscription)
    when :commitment
      commitment_fee_billing_period(fee, invoice_subscription)
    else
      # Fallback to invoice_subscription boundaries
      fallback_billing_period(invoice_subscription)
    end
  end

  def self.group_fees_by_billing_period(fees, invoice_subscription:)
    # Categorize fees by type and billing period
    periods_with_fees = Hash.new do |h, k|
      h[k] = {subscription: nil, fixed_charges: [], charges: [], commitment: nil}
    end

    fees.each do |fee|
      period = billing_period_for(fee, invoice_subscription:)

      case fee.fee_type.to_sym
      when :subscription
        periods_with_fees[period][:subscription] = fee
      when :fixed_charge
        periods_with_fees[period][:fixed_charges] << fee
      when :charge
        periods_with_fees[period][:charges] << fee
      when :commitment
        periods_with_fees[period][:commitment] = fee
      end
    end

    periods_with_fees.map do |period, fee_groups|
      GroupedFees.new(
        billing_period: period,
        subscription_fee: fee_groups[:subscription],
        fixed_charge_fees: sort_fees_alphabetically(fee_groups[:fixed_charges]),
        charge_fees: sort_fees_alphabetically(fee_groups[:charges]),
        commitment_fee: fee_groups[:commitment]
      )
    end.sort_by(&:billing_period)
  end

  def self.format_billing_period(billing_period, customer:)
    timezone = customer.applicable_timezone
    from_date = billing_period.from_datetime&.in_time_zone(timezone)&.to_date
    to_date = billing_period.to_datetime&.in_time_zone(timezone)&.to_date

    I18n.t(
      "invoice.fees_from_to_date",
      from_date: I18n.l(from_date, format: :default),
      to_date: I18n.l(to_date, format: :default)
    )
  end

  def self.subscription_fee_billing_period(fee, invoice_subscription)
    from = fee.properties&.dig("from_datetime")
    to = fee.properties&.dig("to_datetime")

    if from && to
      BillingPeriod.new(from_datetime: from, to_datetime: to)
    else
      fallback_billing_period(invoice_subscription)
    end
  end

  def self.charge_fee_billing_period(fee, invoice_subscription)
    boundaries = fee.date_boundaries
    from = boundaries[:from_date]
    to = boundaries[:to_date]

    if from && to
      BillingPeriod.new(from_datetime: from, to_datetime: to)
    else
      BillingPeriod.new(
        from_datetime: invoice_subscription.charges_from_datetime,
        to_datetime: invoice_subscription.charges_to_datetime
      )
    end
  end

  def self.fixed_charge_fee_billing_period(fee, invoice_subscription)
    from = fee.properties&.dig("fixed_charges_from_datetime")
    to = fee.properties&.dig("fixed_charges_to_datetime")

    if from && to
      BillingPeriod.new(from_datetime: from, to_datetime: to)
    else
      BillingPeriod.new(
        from_datetime: invoice_subscription.fixed_charges_from_datetime,
        to_datetime: invoice_subscription.fixed_charges_to_datetime
      )
    end
  end

  def self.commitment_fee_billing_period(fee, invoice_subscription)
    from = fee.properties&.dig("from_datetime")
    to = fee.properties&.dig("to_datetime")

    if from.present? && to.present?
      BillingPeriod.new(from_datetime: from, to_datetime: to)
    else
      # For legacy commitment fees without properties, derive from invoice subscription
      derive_commitment_billing_period(fee, invoice_subscription)
    end
  end

  def self.derive_commitment_billing_period(fee, invoice_subscription)
    subscription = invoice_subscription.subscription

    # For pay in advance plans, commitment reconciles the PREVIOUS period
    # For pay in arrears plans, commitment reconciles the CURRENT period
    target_invoice_subscription = if subscription.plan.pay_in_advance?
      invoice_subscription.previous_invoice_subscription
    else
      invoice_subscription
    end

    BillingPeriod.new(
      from_datetime: target_invoice_subscription.from_datetime,
      to_datetime: target_invoice_subscription.to_datetime
    )
  end

  def self.fallback_billing_period(invoice_subscription)
    BillingPeriod.new(
      from_datetime: invoice_subscription.from_datetime,
      to_datetime: invoice_subscription.to_datetime
    )
  end

  def self.sort_fees_alphabetically(fees)
    fees.sort_by { |f| f.invoice_sorting_clause.to_s.downcase }
  end

  private_class_method :subscription_fee_billing_period,
    :charge_fee_billing_period,
    :fixed_charge_fee_billing_period,
    :commitment_fee_billing_period,
    :derive_commitment_billing_period,
    :fallback_billing_period,
    :sort_fees_alphabetically
end
