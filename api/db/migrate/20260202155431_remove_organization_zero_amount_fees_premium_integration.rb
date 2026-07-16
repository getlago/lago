# frozen_string_literal: true

class RemoveOrganizationZeroAmountFeesPremiumIntegration < ActiveRecord::Migration[8.0]
  def change
    organizations = Organization.where("? = ANY(premium_integrations)", "zero_amount_fees")

    organizations.find_each do |organization|
      organization.update!(premium_integrations: organization.premium_integrations - ["zero_amount_fees"])
    end
  end
end
