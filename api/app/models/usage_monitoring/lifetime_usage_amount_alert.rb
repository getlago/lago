# frozen_string_literal: true

module UsageMonitoring
  class LifetimeUsageAmountAlert < Alert
    def find_value(lifetime_usage)
      lifetime_usage.total_amount_cents
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
