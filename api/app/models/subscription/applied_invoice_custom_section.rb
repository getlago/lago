# frozen_string_literal: true

class Subscription::AppliedInvoiceCustomSection < ApplicationRecord
  self.table_name = "subscriptions_invoice_custom_sections"

  belongs_to :organization
  belongs_to :subscription
  belongs_to :invoice_custom_section
end

# == Schema Information
#
# Table name: subscriptions_invoice_custom_sections
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  invoice_custom_section_id :uuid             not null
#  organization_id           :uuid             not null
#  subscription_id           :uuid             not null
#
# Indexes
#
#  idx_on_invoice_custom_section_id_d8b9068730                     (invoice_custom_section_id)
#  index_subscriptions_invoice_custom_sections_on_organization_id  (organization_id)
#  index_subscriptions_invoice_custom_sections_on_subscription_id  (subscription_id)
#  index_subscriptions_invoice_custom_sections_unique              (subscription_id,invoice_custom_section_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invoice_custom_section_id => invoice_custom_sections.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
