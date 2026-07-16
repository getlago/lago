# frozen_string_literal: true

class Commitment < ApplicationRecord
  belongs_to :plan
  belongs_to :organization
  has_many :applied_taxes, class_name: "Commitment::AppliedTax", dependent: :destroy
  has_many :taxes, through: :applied_taxes

  COMMITMENT_TYPES = {
    minimum_commitment: 0
  }.freeze

  enum :commitment_type, COMMITMENT_TYPES

  monetize :amount_cents, disable_validation: true, allow_nil: true

  validates :amount_cents, numericality: {greater_than: 0}, allow_nil: false
  validates :commitment_type, uniqueness: {scope: :plan_id}

  def invoice_name
    invoice_display_name.presence || I18n.t("commitment.minimum.name")
  end
end

# == Schema Information
#
# Table name: commitments
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  amount_cents         :bigint           not null
#  commitment_type      :integer          not null
#  invoice_display_name :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  organization_id      :uuid             not null
#  plan_id              :uuid             not null
#
# Indexes
#
#  index_commitments_on_commitment_type_and_plan_id  (commitment_type,plan_id) UNIQUE
#  index_commitments_on_organization_id              (organization_id)
#  index_commitments_on_plan_id                      (plan_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (plan_id => plans.id)
#
