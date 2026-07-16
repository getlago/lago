# frozen_string_literal: true

class CouponTarget < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :coupon
  belongs_to :plan, optional: true
  belongs_to :billable_metric, optional: true
  belongs_to :organization

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: coupon_targets
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  deleted_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  billable_metric_id :uuid
#  coupon_id          :uuid             not null
#  organization_id    :uuid             not null
#  plan_id            :uuid
#
# Indexes
#
#  index_coupon_targets_on_billable_metric_id  (billable_metric_id)
#  index_coupon_targets_on_coupon_id           (coupon_id)
#  index_coupon_targets_on_deleted_at          (deleted_at)
#  index_coupon_targets_on_organization_id     (organization_id)
#  index_coupon_targets_on_plan_id             (plan_id)
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_id => billable_metrics.id)
#  fk_rails_...  (coupon_id => coupons.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (plan_id => plans.id)
#
