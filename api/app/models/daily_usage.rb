# frozen_string_literal: true

class DailyUsage < ApplicationRecord
  DEFAULT_HISTORY_DAYS = 120

  belongs_to :organization
  belongs_to :customer
  belongs_to :subscription

  scope :usage_date_in_timezone, ->(timestamp) do
    at_time_zone = Utils::Timezone.at_time_zone_sql(customer: "cus", billing_entity: "billing_entities")

    joins("INNER JOIN customers AS cus ON daily_usages.customer_id = cus.id")
      .joins("INNER JOIN billing_entities ON cus.billing_entity_id = billing_entities.id")
      .where("DATE((daily_usages.usage_date)#{at_time_zone}) = DATE(:timestamp#{at_time_zone})", timestamp:)
  end
end

# == Schema Information
#
# Table name: daily_usages
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  from_datetime            :datetime         not null
#  refreshed_at             :datetime         not null
#  to_datetime              :datetime         not null
#  usage                    :jsonb            not null
#  usage_date               :date
#  usage_diff               :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  customer_id              :uuid             not null
#  external_subscription_id :string           not null
#  organization_id          :uuid             not null
#  subscription_id          :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_external_subscription_id_df3a30d96d  (organization_id,external_subscription_id)
#  index_daily_usages_on_customer_id                           (customer_id)
#  index_daily_usages_on_organization_id                       (organization_id)
#  index_daily_usages_on_subscription_id                       (subscription_id)
#  index_daily_usages_on_subscription_id_and_usage_date        (subscription_id,usage_date)
#  index_daily_usages_on_usage_date                            (usage_date)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
