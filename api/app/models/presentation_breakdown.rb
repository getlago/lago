# frozen_string_literal: true

class PresentationBreakdown < ApplicationRecord
  belongs_to :organization
  belongs_to :fee
end

# == Schema Information
#
# Table name: presentation_breakdowns
# Database name: primary
#
#  id              :uuid             not null, primary key
#  presentation_by :jsonb            not null
#  units           :decimal(, )      default(0.0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  fee_id          :uuid             not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_presentation_breakdowns_on_fee_id           (fee_id)
#  index_presentation_breakdowns_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (fee_id => fees.id)
#  fk_rails_...  (organization_id => organizations.id)
#
