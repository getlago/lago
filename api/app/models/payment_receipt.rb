# frozen_string_literal: true

class PaymentReceipt < ApplicationRecord
  belongs_to :payment
  belongs_to :organization
  belongs_to :billing_entity

  delegate :customer, to: :payment

  has_one_attached :file
  has_one_attached :xml_file

  def file_url
    return if file.blank?

    Rails.application.routes.url_helpers.rails_blob_url(file, host: ENV["LAGO_API_URL"])
  end

  def xml_url
    return if xml_file.blank?

    Rails.application.routes.url_helpers.rails_blob_url(xml_file, host: ENV["LAGO_API_URL"])
  end
end

# == Schema Information
#
# Table name: payment_receipts
# Database name: primary
#
#  id                :uuid             not null, primary key
#  number            :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  billing_entity_id :uuid             not null
#  organization_id   :uuid             not null
#  payment_id        :uuid             not null
#
# Indexes
#
#  index_payment_receipts_on_billing_entity_id  (billing_entity_id)
#  index_payment_receipts_on_organization_id    (organization_id)
#  index_payment_receipts_on_payment_id         (payment_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_id => payments.id)
#
