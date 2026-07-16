# frozen_string_literal: true

class PaymentRequest
  class AppliedInvoice < ApplicationRecord
    self.table_name = "invoices_payment_requests"

    belongs_to :invoice
    belongs_to :payment_request
    belongs_to :organization
  end
end

# == Schema Information
#
# Table name: invoices_payment_requests
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  invoice_id         :uuid             not null
#  organization_id    :uuid             not null
#  payment_request_id :uuid             not null
#
# Indexes
#
#  idx_on_invoice_id_payment_request_id_aa550779a4        (invoice_id,payment_request_id) UNIQUE
#  index_invoices_payment_requests_on_invoice_id          (invoice_id)
#  index_invoices_payment_requests_on_organization_id     (organization_id)
#  index_invoices_payment_requests_on_payment_request_id  (payment_request_id)
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_request_id => payment_requests.id)
#
