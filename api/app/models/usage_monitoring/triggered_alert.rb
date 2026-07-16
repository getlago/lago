# frozen_string_literal: true

module UsageMonitoring
  class TriggeredAlert < ApplicationRecord
    belongs_to :organization
    belongs_to :subscription, optional: true
    belongs_to :wallet, optional: true
    belongs_to :alert,
      -> { with_discarded },
      foreign_key: "usage_monitoring_alert_id",
      class_name: "UsageMonitoring::Alert"
  end
end

# == Schema Information
#
# Table name: usage_monitoring_triggered_alerts
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  crossed_thresholds        :jsonb
#  current_value             :decimal(30, 5)   not null
#  previous_value            :decimal(30, 5)   not null
#  triggered_at              :datetime         not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  organization_id           :uuid             not null
#  subscription_id           :uuid
#  usage_monitoring_alert_id :uuid             not null
#  wallet_id                 :uuid
#
# Indexes
#
#  idx_on_usage_monitoring_alert_id_4290c95dec                 (usage_monitoring_alert_id)
#  index_usage_monitoring_triggered_alerts_on_organization_id  (organization_id)
#  index_usage_monitoring_triggered_alerts_on_subscription_id  (subscription_id)
#  index_usage_monitoring_triggered_alerts_on_wallet_id        (wallet_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#  fk_rails_...  (usage_monitoring_alert_id => usage_monitoring_alerts.id)
#  fk_rails_...  (wallet_id => wallets.id)
#
