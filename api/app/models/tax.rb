# frozen_string_literal: true

class Tax < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at
  default_scope -> { kept }

  ORDERS = %w[name rate].freeze

  has_many :applied_taxes, class_name: "Customer::AppliedTax", dependent: :destroy
  has_many :customers, through: :applied_taxes

  has_many :billing_entities_taxes, class_name: "BillingEntity::AppliedTax", dependent: :destroy
  has_many :billing_entities, through: :billing_entities_taxes
  has_many :draft_fee_taxes, -> { joins(fee: :invoice).where(invoices: {status: :draft}) }, class_name: "Fee::AppliedTax", dependent: :destroy
  has_many :fees_taxes, class_name: "Fee::AppliedTax"
  has_many :fees, through: :fees_taxes
  has_many :draft_invoice_taxes, -> { joins(:invoice).where(invoices: {status: :draft}) }, class_name: "Invoice::AppliedTax", dependent: :destroy
  has_many :invoices_taxes, class_name: "Invoice::AppliedTax"
  has_many :invoices, through: :invoices_taxes
  has_many :credit_notes_taxes, class_name: "CreditNote::AppliedTax", dependent: :destroy
  has_many :credit_notes, through: :credit_notes_taxes
  has_many :add_ons_taxes, class_name: "AddOn::AppliedTax", dependent: :destroy
  has_many :add_ons, through: :add_ons_taxes
  has_many :plans_taxes, class_name: "Plan::AppliedTax", dependent: :destroy
  has_many :plans, through: :plans_taxes
  has_many :charges_taxes, class_name: "Charge::AppliedTax", dependent: :destroy
  has_many :charges, through: :charges_taxes
  has_many :commitments_taxes, class_name: "Commitment::AppliedTax", dependent: :destroy
  has_many :commitments, through: :commitments_taxes
  has_many :fixed_charges_taxes, class_name: "FixedCharge::AppliedTax", dependent: :destroy
  has_many :fixed_charges, through: :fixed_charges_taxes

  belongs_to :organization

  validates :name, :rate, presence: true
  validates :code, presence: true, uniqueness: {scope: :organization_id}

  scope :applied_to_organization, -> { where(applied_to_organization: true) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code]
  end

  def customers_count
    applicable_customers.count
  end

  def applicable_customers
    # return customers if the tax is not applied to any billing entity (tax is attached only to customers)
    return customers if billing_entities.empty?

    # NOTE: When applied to a billing_entity
    #       customer list = customer without tax in billing_entities with this tax (tax used as default) +
    #                       customer attached to the current tax
    customers_without_taxes_query = organization.customers.left_joins(:applied_taxes)
      .where(billing_entity_id: billing_entities.select(:id))
      .group("customers.id")
      .having("COUNT(customers_taxes.id) = 0")
      .select(:id)
    organization.customers.where(id: customers_without_taxes_query)
      .or(organization.customers.where(id: customers.select(:id)))
  end
end

# == Schema Information
#
# Table name: taxes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  applied_to_organization :boolean          default(FALSE), not null
#  auto_generated          :boolean          default(FALSE), not null
#  code                    :string           not null
#  deleted_at              :datetime
#  description             :string
#  name                    :string           not null
#  rate                    :float            default(0.0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#
# Indexes
#
#  idx_unique_tax_code_per_organization  (code,organization_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_taxes_on_organization_id        (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
