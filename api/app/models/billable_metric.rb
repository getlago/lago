# frozen_string_literal: true

class BillableMetric < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model
  include IntegrationMappable

  self.discard_column = :deleted_at

  belongs_to :organization

  has_many :alerts, class_name: "UsageMonitoring::Alert"
  has_many :charges, dependent: :destroy
  has_many :plans, through: :charges
  has_many :subscriptions, through: :plans
  has_many :fees, through: :charges
  has_many :invoices, through: :fees
  has_many :coupon_targets
  has_many :coupons, through: :coupon_targets
  has_many :groups, dependent: :delete_all
  has_many :filters, -> { order(:key) }, dependent: :delete_all, class_name: "BillableMetricFilter"

  has_many :activity_logs,
    -> { order(logged_at: :desc) },
    class_name: "Clickhouse::ActivityLog",
    as: :resource

  AGGREGATION_TYPES = {
    count_agg: 0,
    sum_agg: 1,
    max_agg: 2,
    unique_count_agg: 3,
    # NOTE: deleted aggregation type, recurring_count_agg: 4,
    weighted_sum_agg: 5,
    latest_agg: 6,
    custom_agg: 7
  }.freeze
  AGGREGATION_TYPES_PAYABLE_IN_ADVANCE = %i[count_agg sum_agg unique_count_agg custom_agg].freeze

  ROUNDING_FUNCTIONS = {round: "round", ceil: "ceil", floor: "floor"}.freeze

  UNIQUE_COUNT_OPERATION_TYPES = %w[add remove].freeze

  WEIGHTED_INTERVAL = {seconds: "seconds"}.freeze

  enum :aggregation_type, AGGREGATION_TYPES
  enum :rounding_function, ROUNDING_FUNCTIONS
  enum :weighted_interval, WEIGHTED_INTERVAL

  validate :validate_recurring
  validate :validate_expression

  validates :name, presence: true
  validates :field_name, presence: true, if: :should_have_field_name?
  validates :aggregation_type, inclusion: {in: AGGREGATION_TYPES.keys.map(&:to_s)}
  validates :code,
    presence: true,
    uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :organization_id}
  validates :weighted_interval,
    inclusion: {in: WEIGHTED_INTERVAL.values},
    if: :weighted_sum_agg?
  validates :custom_aggregator, presence: true, if: :custom_agg?
  validates :rounding_function, inclusion: {in: ROUNDING_FUNCTIONS.values}, allow_nil: true

  default_scope -> { kept }

  scope :with_expression, -> { where("expression IS NOT NULL AND expression <> ''") }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code]
  end

  def attached_subscriptions
    Subscription.where(
      plan_id: Charge.where(
        billable_metric_id: id,
        organization_id:
      ).select(:plan_id),
      organization_id:
    )
  end

  def aggregation_type=(value)
    AGGREGATION_TYPES.key?(value&.to_sym) ? super : nil
  end

  def payable_in_advance?
    AGGREGATION_TYPES_PAYABLE_IN_ADVANCE.include?(aggregation_type.to_sym)
  end

  # NOTE: Replaces billable_metric.plans.exists?
  #       to force planner to use Index Scan (index_charges_on_billable_metric_id) instead of Seq Scan on charges
  def attached_to_plan?
    charges
      .where("EXISTS (SELECT 1 FROM plans WHERE plans.id = charges.plan_id AND plans.deleted_at IS NULL)")
      .exists?
  end

  private

  def should_have_field_name?
    !count_agg? && !custom_agg?
  end

  def validate_recurring
    return unless recurring?
    return unless count_agg? || max_agg? || latest_agg?

    errors.add(:recurring, :not_compatible_with_aggregation_type)
  end

  def validate_expression
    return if expression.blank?
    return if Lago::ExpressionParser.validate(expression).blank?

    errors.add(:expression, :invalid_expression)
  end
end

# == Schema Information
#
# Table name: billable_metrics
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  aggregation_type   :integer          not null
#  code               :string           not null
#  custom_aggregator  :text
#  deleted_at         :datetime
#  description        :string
#  expression         :string
#  field_name         :string
#  name               :string           not null
#  properties         :jsonb
#  recurring          :boolean          default(FALSE), not null
#  rounding_function  :enum
#  rounding_precision :integer
#  weighted_interval  :enum
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  organization_id    :uuid             not null
#
# Indexes
#
#  idx_billable_metrics_id_agg_type                    (id)
#  index_billable_metrics_on_deleted_at                (deleted_at)
#  index_billable_metrics_on_org_id_and_code_and_expr  (organization_id,code,expression) WHERE ((expression IS NOT NULL) AND ((expression)::text <> ''::text))
#  index_billable_metrics_on_organization_id           (organization_id)
#  index_billable_metrics_on_organization_id_and_code  (organization_id,code) UNIQUE WHERE (deleted_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
