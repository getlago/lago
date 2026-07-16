# frozen_string_literal: true

class AppliedAddOn < ApplicationRecord
  include PaperTrailTraceable
  include Currencies

  belongs_to :add_on
  belongs_to :customer

  monetize :amount_cents

  validates :amount_cents, numericality: {greater_than: 0}
  validates :amount_currency, inclusion: {in: currency_list}
end

# == Schema Information
#
# Table name: applied_add_ons
# Database name: primary
#
#  id              :uuid             not null, primary key
#  amount_cents    :bigint           not null
#  amount_currency :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  add_on_id       :uuid             not null
#  customer_id     :uuid             not null
#
# Indexes
#
#  index_applied_add_ons_on_add_on_id                  (add_on_id)
#  index_applied_add_ons_on_add_on_id_and_customer_id  (add_on_id,customer_id)
#  index_applied_add_ons_on_customer_id                (customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (add_on_id => add_ons.id)
#  fk_rails_...  (customer_id => customers.id)
#
