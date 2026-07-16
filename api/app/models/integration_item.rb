# frozen_string_literal: true

class IntegrationItem < ApplicationRecord
  include PaperTrailTraceable

  belongs_to :integration, class_name: "Integrations::BaseIntegration"
  belongs_to :organization

  ITEM_TYPES = [
    :standard,
    :tax,
    :account
  ].freeze

  enum :item_type, ITEM_TYPES

  validates :external_id, presence: true, uniqueness: {scope: %i[integration_id item_type]}

  def self.ransackable_attributes(_auth_object = nil)
    %w[external_account_code external_id external_name]
  end
end

# == Schema Information
#
# Table name: integration_items
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  external_account_code :string
#  external_name         :string
#  item_type             :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  external_id           :string           not null
#  integration_id        :uuid             not null
#  organization_id       :uuid             not null
#
# Indexes
#
#  index_int_items_on_external_id_and_int_id_and_type  (external_id,integration_id,item_type) UNIQUE
#  index_integration_items_on_integration_id           (integration_id)
#  index_integration_items_on_organization_id          (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (integration_id => integrations.id)
#  fk_rails_...  (organization_id => organizations.id)
#
