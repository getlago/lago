# frozen_string_literal: true

return unless ENV["LAGO_CLICKHOUSE_ENABLED"] == "true"

require "factory_bot_rails"

organization = Organization.find_by!(name: "Hooli")
membership = organization.memberships.first
api_key = organization.api_keys.first

invoices = Invoice.where(organization:).order(:created_at).limit(3).to_a
credit_note = CreditNote.find_by(organization:)

# Skip if no documents exist
return if invoices.empty?

# Create payment receipt if needed
payment_receipt = PaymentReceipt.joins(payment: :customer)
  .where(customers: {organization_id: organization.id}).first
if payment_receipt.nil? && invoices[0]
  payment = FactoryBot.create(
    :payment,
    payable: invoices[0],
    organization:,
    customer: invoices[0].customer,
    status: "succeeded"
  )
  payment_receipt = FactoryBot.create(
    :payment_receipt,
    payment:,
    organization:
  )
end

def document_number(document)
  document.number
end

# Build activity_object for ClickHouse Map(String, Nullable(String)) type.
# Nested objects must be serialized to JSON strings for direct writes.
# (When writing via Kafka, ClickHouse auto-converts nested JSON objects to strings.)
# Note: document_type is duplicated at top level for easier querying in seeds.
def email_activity_object(document:, status:, error: nil)
  result = {
    "status" => status,
    "document_type" => document.class.name,
    "email" => {
      subject: "Your #{document.class.name.underscore.humanize} ##{document_number(document)}",
      to: [document.customer.email].compact,
      cc: [],
      bcc: [],
      body_preview: "Dear #{document.customer.name}, please find attached..."
    }.to_json,
    "document" => {
      type: document.class.name,
      number: document_number(document),
      lago_id: document.id
    }.to_json
  }
  result["error"] = error.to_json if error
  result
end

# Check if seed record already exists by unique combination of parameters.
# Uses: activity_source, status, document_type (all from activity_object).
def email_log_exists?(organization:, activity_source:, status:, document_type:)
  Clickhouse::ActivityLog
    .where(organization:, activity_type: "email.sent", activity_source:)
    .where("activity_object['status'] = ?", status)
    .where("activity_object['document_type'] = ?", document_type)
    .exists?
end

# 1. System-triggered email (automatic invoice sending)
if invoices[0] && !email_log_exists?(organization:, activity_source: "system", document_type: "Invoice", status: "sent")
  FactoryBot.create(
    :clickhouse_activity_log,
    organization:,
    resource: invoices[0],
    external_customer_id: invoices[0].customer.external_id,
    user_id: nil,
    api_key_id: nil,
    activity_type: "email.sent",
    activity_source: "system",
    logged_at: 2.days.ago,
    activity_object: email_activity_object(document: invoices[0], status: "sent")
  )
end

# 2. API-triggered email (via API request)
if invoices[1] && !email_log_exists?(organization:, activity_source: "api", document_type: "Invoice", status: "sent")
  FactoryBot.create(
    :clickhouse_activity_log,
    organization:,
    resource: invoices[1],
    external_customer_id: invoices[1].customer.external_id,
    user_id: nil,
    api_key_id: api_key&.id,
    activity_type: "email.sent",
    activity_source: "api",
    logged_at: 1.day.ago,
    activity_object: email_activity_object(document: invoices[1], status: "sent")
  )
end

# 3. UI-triggered resend (user resends from frontend)
if invoices[0] && !email_log_exists?(organization:, activity_source: "front", document_type: "Invoice", status: "resent")
  FactoryBot.create(
    :clickhouse_activity_log,
    organization:,
    resource: invoices[0],
    external_customer_id: invoices[0].customer.external_id,
    user_id: membership&.user_id,
    api_key_id: nil,
    activity_type: "email.sent",
    activity_source: "front",
    logged_at: 1.day.ago,
    activity_object: email_activity_object(document: invoices[0], status: "resent")
  )
end

# 4. Failed email attempt (system)
if invoices[2] && !email_log_exists?(organization:, activity_source: "system", document_type: "Invoice", status: "failed")
  FactoryBot.create(
    :clickhouse_activity_log,
    organization:,
    resource: invoices[2],
    external_customer_id: invoices[2].customer.external_id,
    user_id: nil,
    api_key_id: nil,
    activity_type: "email.sent",
    activity_source: "system",
    logged_at: 12.hours.ago,
    activity_object: email_activity_object(
      document: invoices[2],
      status: "failed",
      error: {class: "Net::SMTPServerBusy", message: "454 Too many connections"}
    )
  )
end

# 5. Credit note email (if exists)
if credit_note && !email_log_exists?(organization:, activity_source: "system", document_type: "CreditNote", status: "sent")
  FactoryBot.create(
    :clickhouse_activity_log,
    organization:,
    resource: credit_note,
    external_customer_id: credit_note.customer.external_id,
    user_id: nil,
    api_key_id: nil,
    activity_type: "email.sent",
    activity_source: "system",
    logged_at: 6.hours.ago,
    activity_object: email_activity_object(document: credit_note, status: "sent")
  )
end

# 6. Payment receipt email (if exists)
if payment_receipt && !email_log_exists?(organization:, activity_source: "system", document_type: "PaymentReceipt", status: "sent")
  FactoryBot.create(
    :clickhouse_activity_log,
    organization:,
    resource: payment_receipt,
    external_customer_id: payment_receipt.customer.external_id,
    user_id: nil,
    api_key_id: nil,
    activity_type: "email.sent",
    activity_source: "system",
    logged_at: 3.hours.ago,
    activity_object: email_activity_object(document: payment_receipt, status: "sent")
  )
end
