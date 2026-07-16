# frozen_string_literal: true

class InvoiceSubscription < ApplicationRecord
  include CustomerTimezone

  belongs_to :invoice
  belongs_to :subscription
  belongs_to :organization

  has_one :customer, through: :subscription

  # NOTE: Readonly fields
  monetize :charge_amount_cents, disable_validation: true, allow_nil: true
  monetize :fixed_charge_amount_cents, disable_validation: true, allow_nil: true
  monetize :subscription_amount_cents, disable_validation: true, allow_nil: true
  monetize :total_amount_cents, disable_validation: true, allow_nil: true

  INVOICING_REASONS = {
    subscription_starting: "subscription_starting",
    subscription_periodic: "subscription_periodic",
    subscription_terminating: "subscription_terminating",
    in_advance_charge: "in_advance_charge",
    in_advance_charge_periodic: "in_advance_charge_periodic",
    progressive_billing: "progressive_billing"
  }.freeze

  enum :invoicing_reason, INVOICING_REASONS

  scope :order_by_charges_to_datetime,
    lambda {
      condition = <<-SQL
            COALESCE(invoice_subscriptions.to_datetime, invoice_subscriptions.created_at) DESC
      SQL

      order(Arel.sql(ActiveRecord::Base.sanitize_sql_for_conditions(condition)))
    }

  scope :order_by_subscription_invoice_name,
    lambda {
      joins(subscription: :plan)
        .order(
          Arel.sql(
            "COALESCE(subscriptions.name, plans.invoice_display_name, plans.name) ASC"
          )
        )
    }

  # NOTE: Billed automatically by the recurring billing process
  #       It is used to prevent double billing on billing day
  scope :recurring, -> { where(recurring: true) }
  scope :starting_from, ->(datetime) {
    where("from_datetime >= ?", datetime)
      .order(Arel.sql("COALESCE(to_datetime, timestamp) ASC"))
  }

  def self.matching?(subscription, boundaries, recurring: true)
    base_query = InvoiceSubscription
      .where(subscription_id: subscription.id)
      .where(from_datetime: boundaries.from_datetime)
      .where(to_datetime: boundaries.to_datetime)

    base_query = base_query.recurring if recurring

    if subscription.plan.charges_billed_in_monthly_split_intervals?
      base_query = base_query
        .where(charges_from_datetime: boundaries.charges_from_datetime)
        .where(charges_to_datetime: boundaries.charges_to_datetime)
    end

    if subscription.plan.fixed_charges_billed_in_monthly_split_intervals?
      base_query = base_query
        .where(fixed_charges_from_datetime: boundaries.fixed_charges_from_datetime)
        .where(fixed_charges_to_datetime: boundaries.fixed_charges_to_datetime)
    end

    base_query.exists?
  end

  def fees
    @fees ||= Fee.where(
      subscription_id: subscription.id,
      invoice_id: invoice.id
    )
  end

  def previous_invoice_subscription
    self.class
      .where(subscription:)
      .where("from_datetime <= ?", from_datetime)
      .where.not(id:)
      .order(from_datetime: :desc)
      .find(&:subscription_fee)
  end

  def charge_amount_cents
    fees.charge.sum(:amount_cents)
  end

  def fixed_charge_amount_cents
    fees.fixed_charge.sum(:amount_cents)
  end

  def subscription_amount_cents
    subscription_fee&.amount_cents || 0
  end

  def subscription_fee
    fees.subscription.first
  end

  def commitment_fee
    fees.commitment.first
  end

  def total_amount_cents
    charge_amount_cents + subscription_amount_cents + fixed_charge_amount_cents
  end

  def total_amount_currency
    subscription.plan.amount_currency
  end

  alias_method :charge_amount_currency, :total_amount_currency
  alias_method :subscription_amount_currency, :total_amount_currency
  alias_method :fixed_charge_amount_currency, :total_amount_currency
end

# == Schema Information
#
# Table name: invoice_subscriptions
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  charges_from_datetime       :datetime
#  charges_to_datetime         :datetime
#  fixed_charges_from_datetime :datetime
#  fixed_charges_to_datetime   :datetime
#  from_datetime               :datetime
#  invoicing_reason            :enum
#  recurring                   :boolean
#  timestamp                   :datetime
#  to_datetime                 :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  invoice_id                  :uuid             not null
#  organization_id             :uuid             not null
#  regenerated_invoice_id      :uuid
#  subscription_id             :uuid             not null
#
# Indexes
#
#  idx_invoice_subscriptions_on_subscription_with_timestamps      (subscription_id, COALESCE(to_datetime, created_at) DESC)
#  index_invoice_subscriptions_boundaries                         (subscription_id,from_datetime,to_datetime)
#  index_invoice_subscriptions_on_invoice_id                      (invoice_id)
#  index_invoice_subscriptions_on_invoice_id_and_subscription_id  (invoice_id,subscription_id) UNIQUE WHERE (created_at >= '2023-11-23 00:00:00'::timestamp without time zone)
#  index_invoice_subscriptions_on_organization_id                 (organization_id)
#  index_invoice_subscriptions_on_regenerated_invoice_id          (regenerated_invoice_id)
#  index_invoice_subscriptions_on_subscription_id                 (subscription_id)
#  index_uniq_invoice_subscriptions_on_charges_from_to_datetime   (subscription_id,charges_from_datetime,charges_to_datetime) UNIQUE WHERE ((created_at >= '2023-06-09 00:00:00'::timestamp without time zone) AND (recurring IS TRUE) AND (regenerated_invoice_id IS NULL))
#  index_uniq_invoice_subscriptions_on_fixed_charges_boundaries   (subscription_id,fixed_charges_from_datetime,fixed_charges_to_datetime) UNIQUE WHERE ((fixed_charges_from_datetime IS NOT NULL) AND (recurring IS TRUE) AND (regenerated_invoice_id IS NULL))
#  index_unique_starting_invoice_subscription                     (subscription_id,invoicing_reason) UNIQUE WHERE ((invoicing_reason = 'subscription_starting'::subscription_invoicing_reason) AND (regenerated_invoice_id IS NULL))
#  index_unique_terminating_invoice_subscription                  (subscription_id,invoicing_reason) UNIQUE WHERE ((invoicing_reason = 'subscription_terminating'::subscription_invoicing_reason) AND (regenerated_invoice_id IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (regenerated_invoice_id => invoices.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
