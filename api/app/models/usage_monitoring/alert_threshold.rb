# frozen_string_literal: true

class UsageMonitoring::AlertThreshold < ApplicationRecord
  SOFT_LIMIT = 20

  belongs_to :organization
  belongs_to :alert,
    foreign_key: "usage_monitoring_alert_id",
    class_name: "UsageMonitoring::Alert"
end

# == Schema Information
#
# Table name: usage_monitoring_alert_thresholds
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  code                      :string
#  recurring                 :boolean          default(FALSE), not null
#  value                     :decimal(30, 5)   not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  organization_id           :uuid             not null
#  usage_monitoring_alert_id :uuid             not null
#
# Indexes
#
#  idx_on_usage_monitoring_alert_id_78eb24d06c                 (usage_monitoring_alert_id)
#  idx_on_usage_monitoring_alert_id_recurring_756a2a370d       (usage_monitoring_alert_id,recurring) UNIQUE WHERE (recurring IS TRUE)
#  index_usage_monitoring_alert_thresholds_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (usage_monitoring_alert_id => usage_monitoring_alerts.id)
#
