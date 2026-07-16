# frozen_string_literal: true

class RemoveOrganizationClickhouseLiveAggregation < ActiveRecord::Migration[8.0]
  def change
    organizations = Organization.where("? = ANY(premium_integrations)", "clickhouse_live_aggregation")

    organizations.find_each do |organization|
      organization.update!(premium_integrations: organization.premium_integrations - ["clickhouse_live_aggregation"])
    end
  end
end
