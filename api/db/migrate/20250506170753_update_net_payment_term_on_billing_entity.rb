# frozen_string_literal: true

class UpdateNetPaymentTermOnBillingEntity < ActiveRecord::Migration[8.0]
  class Organization < ApplicationRecord
    has_many :billing_entities
    has_one :default_billing_entity, -> { active.order(created_at: :asc) }, class_name: "BillingEntity"
  end

  class BillingEntity < ApplicationRecord
    belongs_to :organization
    scope :active, -> { where(archived_at: nil).order(created_at: :asc) }
  end

  def up
    Organization.where.not(net_payment_term: 0).find_each do |organization|
      organization.default_billing_entity.update!(net_payment_term: organization.net_payment_term)
    end
  end

  def down
  end
end
