# frozen_string_literal: true

module UsageMonitoring
  class Alert < ApplicationRecord
    include Discard::Model

    self.discard_column = :deleted_at
    self.inheritance_column = :alert_type

    STI_MAPPING = {
      "current_usage_amount" => "UsageMonitoring::CurrentUsageAmountAlert",
      "billable_metric_current_usage_amount" => "UsageMonitoring::BillableMetricCurrentUsageAmountAlert",
      "billable_metric_current_usage_units" => "UsageMonitoring::BillableMetricCurrentUsageUnitsAlert",
      "lifetime_usage_amount" => "UsageMonitoring::LifetimeUsageAmountAlert",
      "billable_metric_lifetime_usage_units" => "UsageMonitoring::BillableMetricLifetimeUsageUnitsAlert",
      "wallet_balance_amount" => "UsageMonitoring::WalletBalanceAmountAlert",
      "wallet_credits_balance" => "UsageMonitoring::WalletCreditsBalanceAlert",
      "wallet_ongoing_balance_amount" => "UsageMonitoring::WalletOngoingBalanceAmountAlert",
      "wallet_credits_ongoing_balance" => "UsageMonitoring::WalletCreditsOngoingBalanceAlert"
    }

    CURRENT_USAGE_TYPES = %w[current_usage_amount billable_metric_current_usage_amount billable_metric_current_usage_units]
    BILLABLE_METRIC_TYPES = %w[billable_metric_current_usage_amount billable_metric_current_usage_units billable_metric_lifetime_usage_units]
    BILLABLE_METRIC_LIFETIME_USAGE_TYPES = %w[billable_metric_lifetime_usage_units]
    SUBSCRIPTION_TYPES = %w[current_usage_amount billable_metric_current_usage_amount billable_metric_current_usage_units lifetime_usage_amount billable_metric_lifetime_usage_units]
    WALLET_TYPES = %w[wallet_balance_amount wallet_credits_balance wallet_ongoing_balance_amount wallet_credits_ongoing_balance]

    DIRECTIONS = {increasing: "increasing", decreasing: "decreasing"}.freeze

    default_scope -> { kept }

    belongs_to :organization
    belongs_to :billable_metric, -> { with_discarded }, optional: true
    belongs_to :wallet, optional: true

    has_many :thresholds,
      foreign_key: :usage_monitoring_alert_id,
      class_name: "UsageMonitoring::AlertThreshold",
      dependent: :delete_all

    has_many :triggered_alerts,
      foreign_key: :usage_monitoring_alert_id,
      class_name: "UsageMonitoring::TriggeredAlert"

    validates :alert_type, presence: true, inclusion: {in: STI_MAPPING.keys}
    validates :code, presence: true
    validates :billable_metric, presence: true, if: :need_billable_metric?
    validates :billable_metric, absence: true, unless: :need_billable_metric?
    validates :subscription_external_id, presence: true, if: :need_subscription?
    validates :wallet, presence: true, if: :need_wallet?

    scope :using_current_usage, -> { where(alert_type: CURRENT_USAGE_TYPES) }
    scope :using_lifetime_usage, -> { where(alert_type: "lifetime_usage_amount") }
    scope :using_billable_metric_lifetime_usage, -> { where(alert_type: BILLABLE_METRIC_LIFETIME_USAGE_TYPES) }
    scope :using_subscription, -> { where(alert_type: SUBSCRIPTION_TYPES) }
    scope :using_wallet, -> { where(alert_type: WALLET_TYPES) }

    enum :direction, DIRECTIONS, validate: true

    def self.find_sti_class(type_name)
      STI_MAPPING.fetch(type_name).constantize
    end

    def self.sti_name
      STI_MAPPING.invert.fetch(name)
    end

    def find_thresholds_crossed(current)
      if increasing?
        find_thresholds_crossed_increasing(current)
      else
        find_thresholds_crossed_decreasing(current)
      end
    end

    def find_thresholds_crossed_increasing(current)
      crossed = []
      return crossed if current <= previous_value

      if one_time_thresholds_values.present?
        return crossed if current < one_time_thresholds_values.first

        if previous_value < one_time_thresholds_values.last
          crossed += one_time_thresholds_values.filter { it > previous_value && it <= current }
        end
      end

      crossed += find_recurring_thresholds_crossed_increasing(
        previous_value, current, recurring_threshold&.value, one_time_thresholds_values.last || 0
      )

      crossed.uniq.sort
    end

    def find_thresholds_crossed_decreasing(current)
      crossed = []
      return crossed if current >= previous_value

      if one_time_thresholds_values.present?
        return crossed if current > one_time_thresholds_values.last

        if previous_value > one_time_thresholds_values.first
          crossed += one_time_thresholds_values.filter { it < previous_value && it >= current }
        end
      end

      crossed += find_recurring_thresholds_crossed_decreasing(
        previous_value, current, recurring_threshold&.value, one_time_thresholds_values.first || 0
      )

      crossed.uniq.sort
    end

    def recurring_threshold
      @recurring_threshold ||= thresholds.find { |th| th.recurring }
    end

    def one_time_thresholds_values
      @one_time_thresholds_values ||= thresholds.all.filter_map { |th| th.value unless th.recurring }.uniq.sort
    end

    def formatted_crossed_thresholds(crossed_threshold_values)
      regular_thresholds_values, recurring_thresholds_values = crossed_threshold_values.partition do |v|
        one_time_thresholds_values.include?(v)
      end

      formatted_regular_thresholds = thresholds
        .reject { it.recurring }
        .filter { regular_thresholds_values.include?(it.value) }
        .map { |t| {code: t.code, value: t.value, recurring: false} }

      formatted_recurring_thresholds = recurring_thresholds_values
        .map { |v| {code: recurring_threshold&.code, value: v, recurring: true} }

      formatted_regular_thresholds + formatted_recurring_thresholds
    end

    def find_value(current_metrics)
      raise NotImplementedError
    end

    private

    def need_billable_metric?
      BILLABLE_METRIC_TYPES.include?(alert_type)
    end

    def need_wallet?
      WALLET_TYPES.include?(alert_type)
    end

    def need_subscription?
      !need_wallet?
    end

    def find_recurring_thresholds_crossed_increasing(previous, current, step, initial)
      return [] unless step

      previous_steps = ((previous - initial) / step).ceil
      previous_recurring = initial + [previous_steps, 1].max * step

      current_steps = ((current - initial) / step).floor
      current_recurring = initial + current_steps * step

      return [] if previous_recurring > current_recurring # Shouldn't happen

      (previous_recurring..current_recurring).step(step).to_a
    end

    def find_recurring_thresholds_crossed_decreasing(previous, current, step, initial)
      return [] unless step

      previous_steps = ((initial - previous) / step).ceil
      previous_recurring = initial - [previous_steps, 1].max * step

      current_steps = ((initial - current) / step).floor
      current_recurring = initial - current_steps * step

      return [] if previous_recurring < current_recurring # Shouldn't happen

      current_recurring.step(previous_recurring, step).to_a
    end
  end
end

# == Schema Information
#
# Table name: usage_monitoring_alerts
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  alert_type               :enum             not null
#  code                     :string           not null
#  deleted_at               :datetime
#  direction                :enum             default("increasing"), not null
#  last_processed_at        :datetime
#  name                     :string
#  previous_value           :decimal(30, 5)   default(0.0), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  billable_metric_id       :uuid
#  organization_id          :uuid             not null
#  subscription_external_id :string
#  wallet_id                :uuid
#
# Indexes
#
#  idx_alerts_code_unique_per_subscription                    (code,subscription_external_id,organization_id) UNIQUE WHERE (deleted_at IS NULL)
#  idx_alerts_unique_per_type_per_subscription                (subscription_external_id,organization_id,alert_type) UNIQUE WHERE ((billable_metric_id IS NULL) AND (deleted_at IS NULL))
#  idx_alerts_unique_per_type_per_subscription_with_bm        (subscription_external_id,organization_id,alert_type,billable_metric_id) UNIQUE WHERE ((billable_metric_id IS NOT NULL) AND (deleted_at IS NULL))
#  idx_alerts_unique_per_type_per_wallet                      (wallet_id,organization_id,alert_type) UNIQUE WHERE ((billable_metric_id IS NULL) AND (deleted_at IS NULL))
#  index_usage_monitoring_alerts_on_billable_metric_id        (billable_metric_id)
#  index_usage_monitoring_alerts_on_organization_id           (organization_id)
#  index_usage_monitoring_alerts_on_subscription_external_id  (subscription_external_id)
#  index_usage_monitoring_alerts_on_wallet_id                 (wallet_id)
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_id => billable_metrics.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (wallet_id => wallets.id)
#
