# frozen_string_literal: true

class InvoiceCustomSection < ApplicationRecord
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization
  has_many :customer_applied_invoice_custom_sections,
    class_name: "Customer::AppliedInvoiceCustomSection",
    dependent: :destroy
  has_many :billing_entity_applied_invoice_custom_sections,
    class_name: "BillingEntity::AppliedInvoiceCustomSection",
    dependent: :destroy

  SECTION_TYPES = {manual: "manual", system_generated: "system_generated"}.freeze
  enum :section_type, SECTION_TYPES, default: :manual, prefix: :section_type

  validates :name, presence: true
  validates :code,
    presence: true,
    uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :organization_id}

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: invoice_custom_sections
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
#  deleted_at      :datetime
#  description     :string
#  details         :string
#  display_name    :string
#  name            :string           not null
#  section_type    :enum             default("manual"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_deleted_at_225e3f789d               (organization_id,deleted_at)
#  index_invoice_custom_sections_on_organization_id           (organization_id)
#  index_invoice_custom_sections_on_organization_id_and_code  (organization_id,code) UNIQUE WHERE (deleted_at IS NULL)
#  index_invoice_custom_sections_on_section_type              (section_type)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
