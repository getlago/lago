# frozen_string_literal: true

class DataExport < ApplicationRecord
  EXPORT_FORMATS = %w[csv].freeze
  STATUSES = %w[pending processing completed failed].freeze
  EXPIRATION_PERIOD = 7.days

  belongs_to :organization
  belongs_to :membership
  has_one :user, through: :membership

  has_one_attached :file

  has_many :data_export_parts

  enum :format, EXPORT_FORMATS, validate: true
  enum :status, STATUSES, validate: true

  validates :resource_type, presence: true
  validates :file, attached: true, if: :completed?

  def processing!
    update!(status: "processing", started_at: Time.zone.now)
  end

  def completed!
    update!(
      status: "completed",
      completed_at: Time.zone.now,
      expires_at: EXPIRATION_PERIOD.from_now
    )
  end

  def expired?
    return false unless expires_at

    expires_at < Time.zone.now
  end

  def filename
    "#{created_at.strftime("%Y%m%d%H%M%S")}_#{resource_type}.#{format}"
  end

  def file_url
    return if file.blank?

    blob_path = Rails.application.routes.url_helpers.rails_blob_path(
      file,
      host: "void",
      expires_in: EXPIRATION_PERIOD
    )

    File.join(ENV["LAGO_API_URL"], blob_path)
  end

  def export_class
    case resource_type
    when "credit_notes" then DataExports::Csv::CreditNotes
    when "credit_note_items" then DataExports::Csv::CreditNoteItems
    when "invoices" then DataExports::Csv::Invoices
    when "invoice_fees" then DataExports::Csv::InvoiceFees
    end
  end
end

# == Schema Information
#
# Table name: data_exports
# Database name: primary
#
#  id              :uuid             not null, primary key
#  completed_at    :datetime
#  expires_at      :datetime
#  format          :integer
#  resource_query  :jsonb
#  resource_type   :string           not null
#  started_at      :datetime
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  membership_id   :uuid
#  organization_id :uuid             not null
#
# Indexes
#
#  index_data_exports_on_membership_id    (membership_id)
#  index_data_exports_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (membership_id => memberships.id)
#  fk_rails_...  (organization_id => organizations.id)
#
