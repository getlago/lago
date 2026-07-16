# frozen_string_literal: true

class CreateSubscriptionActivationRuleStatuses < ActiveRecord::Migration[8.0]
  def up
    create_enum :subscription_activation_rule_statuses,
      %w[inactive pending satisfied declined failed expired not_applicable]
  end

  def down
    drop_enum :subscription_activation_rule_statuses
  end
end
