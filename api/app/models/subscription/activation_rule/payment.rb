# frozen_string_literal: true

class Subscription::ActivationRule::Payment < Subscription::ActivationRule
  def applicable?
    return true if subscription.plan.pay_in_advance? && !subscription.in_trial_period?
    return true if has_pay_in_advance_fixed_charges?

    false
  end

  private

  def has_pay_in_advance_fixed_charges?
    subscription.fixed_charges.pay_in_advance.any?
  end
end

# == Schema Information
#
# Table name: subscription_activation_rules
# Database name: primary
#
#  id              :uuid             not null, primary key
#  expires_at      :datetime
#  status          :enum             default("inactive"), not null
#  timeout_hours   :integer          default(0), not null
#  type            :enum             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  subscription_id :uuid             not null
#
# Indexes
#
#  idx_on_subscription_id_type_8feb7b9623                  (subscription_id,type) UNIQUE
#  index_activation_rules_pending_with_expiry              (status,expires_at) WHERE ((status = 'pending'::subscription_activation_rule_statuses) AND (expires_at IS NOT NULL))
#  index_subscription_activation_rules_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
