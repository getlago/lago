# frozen_string_literal: true

module Subscriptions
  class DatesService
    def self.new_instance(subscription, billing_at, current_usage: false)
      klass = case subscription.plan.interval&.to_sym
      when :weekly
        Subscriptions::Dates::WeeklyService
      when :monthly
        Subscriptions::Dates::MonthlyService
      when :yearly
        Subscriptions::Dates::YearlyService
      when :quarterly
        Subscriptions::Dates::QuarterlyService
      when :semiannual
        Subscriptions::Dates::SemiannualService
      else
        raise(NotImplementedError)
      end

      klass.new(subscription, billing_at, current_usage)
    end

    # Note: For context, the notion of `(from|to)_datetime` vs `charges_(from|to)_datetime` was introduced BEFORE
    #       pay in advance charges were introduced. Pay in Advance charges should mostly use `(from|to)_datetime` range.
    #       The boundaries might need a third range, like `in_advance_charges_(from|to)_datetime` for instance.
    #       Ideally, we should also store the dates on EACH FEE.
    def self.charge_pay_in_advance_interval(timestamp, subscription)
      date_service = new_instance(
        subscription,
        Time.zone.at(timestamp),
        current_usage: true
      )

      {
        charges_from_date: date_service.charges_from_datetime&.to_date,
        charges_to_date: date_service.charges_to_datetime&.to_date
      }
    end

    def self.fixed_charge_pay_in_advance_interval(timestamp, subscription)
      date_service = new_instance(
        subscription,
        Time.zone.at(timestamp),
        current_usage: true
      )

      {
        fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
        fixed_charges_to_datetime: date_service.fixed_charges_to_datetime,
        fixed_charges_duration: date_service.fixed_charges_duration_in_days
      }
    end

    def initialize(subscription, billing_at, current_usage)
      @subscription = subscription

      # NOTE: Billing time should usually be the end of the billing period + 1 day
      #       When subscription is terminated, it is the termination day
      @billing_at = billing_at
      @current_usage = current_usage
    end

    def from_datetime
      return @from_datetime if @from_datetime
      return unless subscription.started_at

      @from_datetime = customer_timezone_shift(compute_from_date)

      # NOTE: On first billing period, subscription might start after the computed start of period
      #       ie: if we bill on beginning of period, and user registered on the 15th, the invoice should
      #       start on the 15th (subscription date) and not on the 1st
      if @from_datetime < subscription.started_at
        @from_datetime = subscription.started_at.in_time_zone(customer.applicable_timezone).beginning_of_day.utc
      end

      @from_datetime
    end

    def to_datetime
      return @to_datetime if @to_datetime
      return unless subscription.started_at

      @to_datetime = customer_timezone_shift(compute_to_date, end_of_day: true)
      terminated_at = subscription.terminated_at&.to_time&.round

      if subscription.terminated_at?(billing_at) && @to_datetime > terminated_at
        @to_datetime = terminated_at
      end

      @to_datetime = subscription.started_at if @to_datetime < subscription.started_at
      @to_datetime
    end

    def charges_from_datetime
      return unless subscription.started_at
      return unless should_fill_charges_boundaries?

      datetime = customer_timezone_shift(compute_charges_from_date)

      # NOTE: If customer applicable timezone changes during a billing period, there is a risk to double count events
      #       or to miss some. To prevent it, we have to ensure that invoice bounds does not overlap or that there is no
      #       hole between a charges_from_datetime and the charges_to_datetime of the previous period
      if timezone_has_changed? && previous_charge_to_datetime
        new_datetime = previous_charge_to_datetime + 1.second

        # NOTE: Ensure that the invoice is really the previous one
        #       26 hours is the maximum time difference between two places in the world
        datetime = new_datetime if ((datetime.in_time_zone - new_datetime.in_time_zone) / 1.hour).abs < 26
      end

      datetime = subscription.started_at if datetime < subscription.started_at

      datetime
    end

    def charges_to_datetime
      return unless subscription.started_at
      return unless should_fill_charges_boundaries?

      datetime = customer_timezone_shift(compute_charges_to_date, end_of_day: true)
      datetime = subscription.terminated_at if subscription.terminated? && subscription.terminated_at <= datetime
      datetime = subscription.started_at if datetime < subscription.started_at

      datetime
    end

    def fixed_charges_from_datetime
      return unless subscription.started_at
      return unless should_fill_fixed_charges_boundaries?

      datetime = customer_timezone_shift(compute_fixed_charges_from_date)

      # NOTE: If customer applicable timezone changes during a billing period, there is a risk to double count events
      #       or to miss some. To prevent it, we have to ensure that invoice bounds does not overlap or that there is no
      #       hole between a fixed_charges_from_datetime and the fixed_charges_to_datetime of the previous period
      if timezone_has_changed? && previous_fixed_charge_to_datetime
        new_datetime = previous_fixed_charge_to_datetime + 1.second

        # NOTE: Ensure that the invoice is really the previous one
        #       26 hours is the maximum time difference between two places in the world
        datetime = new_datetime if ((datetime.in_time_zone - new_datetime.in_time_zone) / 1.hour).abs < 26
      end

      datetime = subscription.started_at if datetime < subscription.started_at

      datetime
    end

    def fixed_charges_to_datetime
      return unless subscription.started_at
      return unless should_fill_fixed_charges_boundaries?

      datetime = customer_timezone_shift(compute_fixed_charges_to_date, end_of_day: true)
      datetime = subscription.terminated_at if subscription.terminated? && subscription.terminated_at <= datetime
      datetime = subscription.started_at if datetime < subscription.started_at

      datetime
    end

    def next_end_of_period
      end_utc = compute_next_end_of_period
      customer_timezone_shift(end_utc, end_of_day: true)
    end

    def end_of_period
      end_utc = compute_to_date
      customer_timezone_shift(end_utc, end_of_day: true)
    end

    # Start of the billing period that follows the current one, at the beginning of the day in the
    # customer timezone. `end_of_period` lands at the end of the day, so the next period starts the
    # following day at 00:00.
    def next_period_started_at
      (end_of_period + 1.day).in_time_zone(customer.applicable_timezone).beginning_of_day
    end

    # NOTE: Retrieve the beginning of the previous period based on the billing date
    def previous_beginning_of_period(current_period: false)
      date = base_date
      date = billing_date if current_period

      beginning_utc = compute_previous_beginning_of_period(date)
      customer_timezone_shift(beginning_utc)
    end

    def single_day_price(optional_from_date: nil, plan_amount_cents: nil)
      duration = compute_duration(from_date: optional_from_date || compute_from_date)
      (plan_amount_cents || plan.amount_cents).fdiv(duration.to_i)
    end

    def charges_duration_in_days
      compute_charges_duration(from_date: compute_charges_from_date)
    end

    def fixed_charges_duration_in_days
      compute_fixed_charges_duration(from_date: compute_fixed_charges_from_date)
    end

    private

    attr_accessor :subscription, :billing_at, :current_usage

    delegate :plan, :calendar?, :customer, to: :subscription

    # Determines if charges should be billed this cycle
    # general approach is: yes, some exceptions are for yearly/semiannual plans with monthly charges/fixed_charges
    def should_fill_charges_boundaries?
      true
    end

    # Determines if fixed charges should be billed this cycle
    # general approach is: yes, some exceptions are for yearly/semiannual plans with monthly charges/fixed_charges
    def should_fill_fixed_charges_boundaries?
      true
    end

    def billing_date
      @billing_date ||= billing_at.in_time_zone(customer.applicable_timezone).to_date
    end

    def base_date
      @base_date ||= current_usage ? billing_date : compute_base_date
    end

    def subscription_at
      subscription.subscription_at.in_time_zone(customer.applicable_timezone)
    end

    # NOTE: This method converts a DAY epress in the customer timezone into a proper UTC datetime
    #       Example: `2024-03-01` in `America/New_York` will be converted to `2024-03-01T05:00:00 UTC`
    def customer_timezone_shift(date, end_of_day: false)
      result = date.in_time_zone(customer.applicable_timezone)
      result = result.end_of_day if end_of_day
      result.utc
    end

    def last_invoice_subscription
      @last_invoice_subscription ||= subscription
        .invoice_subscriptions
        .order_by_charges_to_datetime
        .first
    end

    def timezone_has_changed?
      return false if last_invoice_subscription.blank?

      last_invoice_subscription.invoice.timezone != customer.applicable_timezone
    end

    def previous_charge_to_datetime
      return if last_invoice_subscription.blank?

      last_invoice_subscription.charges_to_datetime
    end

    def previous_fixed_charge_to_datetime
      return if last_invoice_subscription.blank?

      last_invoice_subscription.fixed_charges_to_datetime
    end

    def terminated_pay_in_arrears?
      # NOTE: In case of termination or upgrade when we are terminating old plan (paying in arrear),
      #       we should take to the beginning of the billing period
      subscription.terminated_at?(billing_at) && plan.pay_in_arrears? && !subscription.downgraded?
    end

    def terminated?
      subscription.terminated_at?(billing_at) && !subscription.next_subscription
    end

    # NOTE: Handle leap years and anniversary date > 28
    def build_date(year, month, day)
      if day.zero?
        day = 31
        month -= 1

        if month.zero?
          month = 12
          year -= 1
        end
      end

      days_count_in_month = Time.days_in_month(month, year)
      day = days_count_in_month if days_count_in_month < day

      Date.new(year, month, day)
    end

    def last_day_of_month?(date)
      date.day == date.end_of_month.day
    end

    def compute_base_date
      raise(NotImplementedError)
    end

    def compute_from_date
      raise(NotImplementedError)
    end

    def compute_to_date
      raise(NotImplementedError)
    end

    def compute_charges_from_date
      raise(NotImplementedError)
    end

    def compute_charges_to_date
      raise(NotImplementedError)
    end

    def compute_fixed_charges_from_date
      raise(NotImplementedError)
    end

    def compute_fixed_charges_to_date
      raise(NotImplementedError)
    end

    def compute_next_end_of_period
      raise(NotImplementedError)
    end

    def first_month_in_yearly_period?
      false
    end

    def first_month_in_first_yearly_period?
      false
    end

    def first_month_in_semiannual_period?
      false
    end

    def first_month_in_first_semiannual_period?
      false
    end

    def compute_duration(from_date:)
      raise(NotImplementedError)
    end
  end
end
