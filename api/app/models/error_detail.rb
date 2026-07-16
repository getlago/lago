# frozen_string_literal: true

class ErrorDetail < ApplicationRecord
  include Discard::Model

  self.discard_column = :deleted_at
  default_scope -> { kept }

  belongs_to :owner, polymorphic: true
  belongs_to :organization

  ERROR_CODES = {
    not_provided: 0,
    tax_error: 1,
    tax_voiding_error: 2,
    invoice_generation_error: 3
  }.freeze
  enum :error_code, ERROR_CODES, validate: true

  def self.create_generation_error_for(invoice:, error:)
    return unless invoice
    instance = find_or_create_by(owner: invoice, error_code: "invoice_generation_error", organization: invoice.organization)
    instance.update(
      details: {
        backtrace: error.backtrace,
        error: error.inspect.to_json,
        invoice: invoice.to_json(except: [:file, :xml_file]),
        subscriptions: invoice.subscriptions.to_json
      }
    )
    instance
  end
end

# == Schema Information
#
# Table name: error_details
# Database name: primary
#
#  id              :uuid             not null, primary key
#  deleted_at      :datetime
#  details         :jsonb            not null
#  error_code      :integer          default("not_provided"), not null
#  owner_type      :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  owner_id        :uuid             not null
#
# Indexes
#
#  index_error_details_on_deleted_at       (deleted_at)
#  index_error_details_on_error_code       (error_code)
#  index_error_details_on_organization_id  (organization_id)
#  index_error_details_on_owner            (owner_type,owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
