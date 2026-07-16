# frozen_string_literal: true

class CreateSubscriptionActivationRuleTypes < ActiveRecord::Migration[8.0]
  def up
    create_enum :subscription_activation_rule_types, %w[payment]
  end

  def down
    drop_enum :subscription_activation_rule_types
  end
end
