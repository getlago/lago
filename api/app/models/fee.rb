# frozen_string_literal: true

class Fee < ApplicationRecord
  include Currencies
  include Discard::Model

  self.discard_column = :deleted_at
  self.ignored_columns += %w[duplicated_in_advance]
  default_scope -> { kept }

  belongs_to :invoice, optional: true
  belongs_to :charge, -> { with_discarded }, optional: true
  belongs_to :add_on, -> { with_discarded }, optional: true
  belongs_to :applied_add_on, optional: true
  belongs_to :subscription, optional: true
  belongs_to :charge_filter, -> { with_discarded }, optional: true
  belongs_to :group, -> { with_discarded }, optional: true
  belongs_to :invoiceable, polymorphic: true, optional: true
  belongs_to :true_up_parent_fee, class_name: "Fee", optional: true
  belongs_to :original_fee, class_name: "Fee", optional: true # Points to the root fee in a void/regenerate chain
  belongs_to :organization
  belongs_to :billing_entity
  belongs_to :fixed_charge, -> { with_discarded }, optional: true

  has_one :adjusted_fee, dependent: :nullify
  has_one :billable_metric, -> { with_discarded }, through: :charge
  has_one :fixed_charge_add_on, -> { with_discarded }, class_name: "AddOn", through: :fixed_charge, source: :add_on
  has_one :customer, through: :subscription
  has_one :pricing_unit_usage, dependent: :destroy
  has_one :true_up_fee, class_name: "Fee", foreign_key: :true_up_parent_fee_id, dependent: :destroy

  has_many :credit_note_items, dependent: :destroy
  has_many :credit_notes, through: :credit_note_items

  has_many :applied_taxes, class_name: "Fee::AppliedTax", dependent: :destroy
  has_many :taxes, through: :applied_taxes
  has_many :presentation_breakdowns, dependent: :destroy

  monetize :amount_cents
  monetize :taxes_amount_cents, with_model_currency: :currency
  monetize :total_amount_cents
  monetize :precise_amount_cents, with_model_currency: :currency
  monetize :taxes_precise_amount_cents, with_model_currency: :currency
  monetize :precise_total_amount_cents
  monetize :unit_amount_cents, disable_validation: true, allow_nil: true, with_model_currency: :currency

  # TODO: Deprecate add_on type in the near future
  FEE_TYPES = %i[charge add_on subscription credit commitment fixed_charge].freeze
  PAYMENT_STATUS = %i[pending succeeded failed refunded].freeze

  enum :fee_type, FEE_TYPES
  enum :payment_status, PAYMENT_STATUS, prefix: :payment

  validates :amount_currency, inclusion: {in: currency_list}
  validates :units, numericality: {greater_than_or_equal_to: 0}
  validates :events_count, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :true_up_fee_id, presence: false, unless: :charge?
  validates :total_aggregated_units, presence: true, if: :charge?

  scope :positive_units, -> { where("fees.units > ?", 0) }

  # NOTE: pay_in_advance fees are not be linked to any invoice, but add_on fees does not have any subscriptions
  #       so we need a bit of logic to find the fee in the right organization scope
  scope :from_organization, ->(org) { where(organization_id: org.id) }
  scope :from_organization_pay_in_advance, ->(org) { from_organization(org).where(invoice_id: nil) }

  scope :from_customer,
    lambda { |org, external_customer_id|
      union = [from_customer_invoice(org, external_customer_id), from_customer_pay_in_advance(org, external_customer_id)]
        .map(&:to_sql)
        .join(") UNION (")
      unionized_sql = "((#{union})) #{table_name}"
      from(unionized_sql)
    }

  scope :from_customer_invoice, ->(org, external_customer_id) do
    from_organization(org)
      .joins(invoice: :customer)
      .where(customer: {external_id: external_customer_id})
  end
  scope :from_customer_pay_in_advance, ->(org, external_customer_id) do
    from_organization_pay_in_advance(org).joins(subscription: :customer).where("customers.external_id = ?", external_customer_id)
  end
  scope :ordered_by_period, -> do
    from = Arel.sql("(properties->>'from_datetime')::timestamptz NULLS LAST")
    to = Arel.sql("(properties->>'to_datetime')::timestamptz NULLS LAST")

    order(from, to)
  end

  def item_key
    id || object_id
  end

  def item_id
    return billable_metric.id if charge?
    return add_on.id if add_on?
    return invoiceable_id if credit?
    return fixed_charge_add_on.id if fixed_charge?

    subscription_id
  end

  def item_type
    return BillableMetric.name if charge?
    return AddOn.name if add_on?
    return WalletTransaction.name if credit?
    return AddOn.name if fixed_charge?

    Subscription.name
  end

  def item_code
    return billable_metric.code if charge?
    return add_on.code if add_on?
    return fee_type if credit?
    return fixed_charge_add_on.code if fixed_charge?

    subscription.plan.code
  end

  def item_name
    return billable_metric.name if charge?
    return add_on.name if add_on?
    return invoiceable&.name.presence || fee_type if credit?
    return fixed_charge_add_on.name if fixed_charge?

    subscription.plan.name
  end

  def item_source
    return fixed_charge_add_on.code if fixed_charge?
    return add_on.code if add_on?
    return "consumed_credits" if credit?

    subscription&.plan&.code.presence || billable_metric&.code
  end

  def item_description
    return billable_metric.description if charge?
    return add_on.description if add_on?
    return fee_type if credit?
    return fixed_charge_add_on.description if fixed_charge?

    subscription.plan.description
  end

  def invoice_name
    return invoice_display_name if invoice_display_name.present?
    return charge.invoice_display_name.presence || billable_metric.name if charge?
    return add_on.invoice_name if add_on?
    return invoiceable&.name.presence || fee_type if credit?
    return fixed_charge.invoice_display_name.presence || fixed_charge_add_on.invoice_name if fixed_charge?

    subscription.invoice_name
  end

  def filter_display_name(separator: ", ")
    charge_filter&.display_name(separator:)
  end

  def grouped_by_display
    return "" if !charge? || grouped_by.values.compact.blank?

    " • #{grouped_by.values.compact.join(" • ")}"
  end

  def invoice_sorting_clause
    base_clause = "#{invoice_name} #{filter_display_name}".downcase

    return base_clause unless charge?
    return base_clause if grouped_by.blank?

    "#{invoice_name} #{grouped_by.values.join} #{filter_display_name}".downcase
  end

  def currency
    amount_currency
  end

  def grouped_or_filtered?
    grouped_by.present? || charge_filter_id.present?
  end

  def ungrouped_or_filtered?
    grouped_by.blank? || charge_filter_id.present?
  end

  def presentation_group_keys_values_displayed_in_invoice
    return [] unless charge

    @presentation_group_keys_values_displayed_in_invoice ||= charge.presentation_group_keys_values_displayed_in_invoice
  end

  def presentation_breakdowns_displayed_in_invoice
    keys = presentation_group_keys_values_displayed_in_invoice

    return [] if keys.blank?

    if defined?(@presentation_breakdowns_displayed_in_invoice)
      return @presentation_breakdowns_displayed_in_invoice
    end

    rows = Hash.new(0)
    presentation_breakdowns.each do |breakdown|
      presentation_by = breakdown.presentation_by
      values = keys.filter_map { |key| [key, presentation_by[key]] if presentation_by.key?(key) }

      next if values.empty?

      rows[values] += breakdown.units
    end

    @presentation_breakdowns_displayed_in_invoice = rows.map { |values, units| PresentationBreakdown.new(fee: self, presentation_by: values.to_h, units:) }
  end

  def basic_rate_percentage?
    return false unless charge?
    return false unless charge.percentage?

    if charge_filter
      charge_filter.properties.keys == ["rate"]
    else
      charge.properties.keys == ["rate"]
    end
  end

  def compute_precise_credit_amount_cents(credit_amount, base_amount_cents)
    return 0 if base_amount_cents.zero?

    (credit_amount * (amount_cents - precise_coupons_amount_cents)).fdiv(base_amount_cents)
  end

  def sub_total_excluding_taxes_amount_cents
    amount_cents - precise_coupons_amount_cents
  end

  def sub_total_excluding_taxes_precise_amount_cents
    precise_amount_cents - precise_coupons_amount_cents
  end

  def total_amount_cents
    amount_cents + taxes_amount_cents
  end
  alias_method :total_amount_currency, :currency

  def precise_total_amount_cents
    precise_amount_cents + taxes_precise_amount_cents
  end
  alias_method :precise_total_amount_currency, :currency

  def offsettable_amount_cents
    if invoice.credit? && (invoice.payment_pending? || invoice.payment_failed?)
      return amount_cents
    end

    creditable_amount_cents
  end

  def creditable_amount_cents
    remaining_amount = amount_cents - credit_note_items.sum(:amount_cents)

    if credit?
      return [remaining_amount, creditable_from_wallet_amount_cents].min
    end

    remaining_amount
  end

  def creditable_from_wallet_amount_cents
    return 0 unless credit? && active_prepaid_credit_fee_wallet?

    if prepaid_credit_fee_wallet.traceable?
      invoiceable.remaining_amount_cents || 0
    else
      prepaid_credit_fee_wallet.balance_cents
    end
  end

  def prepaid_credit_fee_wallet
    return unless credit?

    # For historical fees, the invoiceable association might be missing, so we need to handle that case.
    return unless invoiceable

    # For historical wallet transaction, the wallet association might be missing, so may return nil.
    invoiceable.wallet
  end

  # There are add_on type and one_off type so in order not to mix those two types with associations,
  # this method is added to handle it. In the near future we will deprecate add_on type and remove this method
  def add_on
    return @add_on if defined? @add_on

    return super if add_on_id.present?
    return unless add_on?

    @add_on = AddOn.with_discarded.find_by(id: applied_add_on.add_on_id)
  end

  def has_charge_filters?
    charge&.filters&.any?
  end

  def non_zero?
    units.positive? || amount_cents.positive? || events_count.to_i.positive?
  end

  def taxable?
    amount_cents.positive?
  end

  def date_boundaries
    if charge? && !pay_in_advance? && charge.pay_in_advance?
      timestamp = invoice.invoice_subscription(subscription.id).timestamp
      interval = ::Subscriptions::DatesService.charge_pay_in_advance_interval(timestamp, subscription)

      return {
        from_date: interval[:charges_from_date]&.to_datetime&.iso8601,
        to_date: interval[:charges_to_date]&.to_datetime&.end_of_day&.iso8601
      }
    end

    if charge? && !charge.invoiceable? && pay_in_advance?
      timestamp = Time.parse(properties["timestamp"]).to_i
      interval = ::Subscriptions::DatesService.charge_pay_in_advance_interval(timestamp, subscription)

      return {
        from_date: interval[:charges_from_date]&.to_datetime&.iso8601,
        to_date: interval[:charges_to_date]&.to_datetime&.end_of_day&.iso8601
      }
    end

    {
      from_date:,
      to_date:
    }
  end

  private

  def active_prepaid_credit_fee_wallet?
    prepaid_credit_fee_wallet&.active?
  end

  def from_date
    property = if charge?
      "charges_from_datetime"
    elsif fixed_charge?
      "fixed_charges_from_datetime"
    else
      "from_datetime"
    end
    properties[property]&.to_datetime&.iso8601
  end

  def to_date
    property = if charge?
      "charges_to_datetime"
    elsif fixed_charge?
      "fixed_charges_to_datetime"
    else
      "to_datetime"
    end
    properties[property]&.to_datetime&.iso8601
  end
end

# == Schema Information
#
# Table name: fees
# Database name: primary
#
#  id                                  :uuid             not null, primary key
#  amount_cents                        :bigint           not null
#  amount_currency                     :string           not null
#  amount_details                      :jsonb            not null
#  deleted_at                          :datetime
#  description                         :string
#  events_count                        :integer
#  failed_at                           :datetime
#  fee_type                            :integer
#  grouped_by                          :jsonb            not null
#  invoice_display_name                :string
#  invoiceable_type                    :string
#  pay_in_advance                      :boolean          default(FALSE), not null
#  payment_status                      :integer          default("pending"), not null
#  precise_amount_cents                :decimal(40, 15)  default(0.0), not null
#  precise_coupons_amount_cents        :decimal(30, 5)   default(0.0), not null
#  precise_credit_notes_amount_cents   :decimal(30, 5)   default(0.0), not null
#  precise_unit_amount                 :decimal(30, 15)  default(0.0), not null
#  properties                          :jsonb            not null
#  refunded_at                         :datetime
#  succeeded_at                        :datetime
#  taxes_amount_cents                  :bigint           not null
#  taxes_base_rate                     :float            default(1.0), not null
#  taxes_precise_amount_cents          :decimal(40, 15)  default(0.0), not null
#  taxes_rate                          :float            default(0.0), not null
#  total_aggregated_units              :decimal(, )
#  unit_amount_cents                   :bigint           default(0), not null
#  units                               :decimal(, )      default(0.0), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  add_on_id                           :uuid
#  applied_add_on_id                   :uuid
#  billing_entity_id                   :uuid             not null
#  charge_filter_id                    :uuid
#  charge_id                           :uuid
#  fixed_charge_id                     :uuid
#  group_id                            :uuid
#  invoice_id                          :uuid
#  invoiceable_id                      :uuid
#  organization_id                     :uuid             not null
#  original_fee_id                     :uuid
#  pay_in_advance_event_id             :uuid
#  pay_in_advance_event_transaction_id :string
#  subscription_id                     :uuid
#  true_up_parent_fee_id               :uuid
#
# Indexes
#
#  idx_pay_in_advance_duplication_guard_charge          (pay_in_advance_event_transaction_id,charge_id) UNIQUE WHERE ((deleted_at IS NULL) AND (charge_filter_id IS NULL) AND (pay_in_advance_event_transaction_id IS NOT NULL) AND (pay_in_advance = true) AND (duplicated_in_advance = false) AND (original_fee_id IS NULL))
#  idx_pay_in_advance_duplication_guard_charge_filter   (pay_in_advance_event_transaction_id,charge_id,charge_filter_id) UNIQUE WHERE ((deleted_at IS NULL) AND (charge_filter_id IS NOT NULL) AND (pay_in_advance_event_transaction_id IS NOT NULL) AND (pay_in_advance = true) AND (duplicated_in_advance = false) AND (original_fee_id IS NULL))
#  index_fees_on_add_on_id                              (add_on_id)
#  index_fees_on_applied_add_on_id                      (applied_add_on_id)
#  index_fees_on_billing_entity_id                      (billing_entity_id)
#  index_fees_on_charge_filter_id                       (charge_filter_id)
#  index_fees_on_charge_id                              (charge_id)
#  index_fees_on_charge_id_and_invoice_id               (charge_id,invoice_id) WHERE (deleted_at IS NULL)
#  index_fees_on_deleted_at                             (deleted_at)
#  index_fees_on_fixed_charge_id                        (fixed_charge_id)
#  index_fees_on_group_id                               (group_id)
#  index_fees_on_invoice_id                             (invoice_id)
#  index_fees_on_invoiceable                            (invoiceable_type,invoiceable_id)
#  index_fees_on_organization_id                        (organization_id)
#  index_fees_on_organization_id_and_created_at_and_id  (organization_id,created_at,id) WHERE (deleted_at IS NULL)
#  index_fees_on_original_fee_id                        (original_fee_id)
#  index_fees_on_pay_in_advance_event_transaction_id    (pay_in_advance_event_transaction_id) WHERE (deleted_at IS NULL)
#  index_fees_on_subscription_id                        (subscription_id)
#  index_fees_on_true_up_parent_fee_id                  (true_up_parent_fee_id)
#
# Foreign Keys
#
#  fk_rails_...  (add_on_id => add_ons.id)
#  fk_rails_...  (applied_add_on_id => applied_add_ons.id)
#  fk_rails_...  (billing_entity_id => billing_entities.id)
#  fk_rails_...  (charge_id => charges.id)
#  fk_rails_...  (fixed_charge_id => fixed_charges.id)
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (original_fee_id => fees.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#  fk_rails_...  (true_up_parent_fee_id => fees.id)
#
