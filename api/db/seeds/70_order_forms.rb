# frozen_string_literal: true

# NOTE: If hooli is not found, run 01_base.rb first
@organization = Organization.find_by!(name: "Hooli")
@customer = Customer.find_by!(external_id: "cust_john-doe")

def create_quote(organization:, customer:, **params)
  quote = ::Quote.new(
    organization: organization,
    customer: customer,
    **params
  )
  quote.save!
  quote
end

def create_quote_version(quote:, **params)
  quote_version = ::QuoteVersion.new(
    quote: quote,
    organization: quote.organization,
    **params
  )
  quote_version.save!
  quote_version
end

def create_order_form(quote_version:, status: :generated, expires_at: nil)
  attrs = {
    organization: quote_version.organization,
    customer: quote_version.quote.customer,
    quote_version: quote_version,
    status: status,
    expires_at: expires_at
  }

  case status
  when :signed
    attrs[:signed_at] = 1.day.ago
  when :expired
    attrs[:expires_at] = 2.days.ago
    attrs[:voided_at] = 1.day.ago
    attrs[:void_reason] = :expired
  when :voided
    attrs[:voided_at] = 1.day.ago
    attrs[:void_reason] = :manual
  end

  OrderForm.create!(attrs)
end

# Create a chain of quotes
def create_quote_chain(organization:, customer:, versions_count: 3)
  quote = create_quote(
    organization: organization,
    customer: customer,
    order_type: :subscription_creation
  )
  owners = User.where(email: ["gavin@hooli.com", "dinesh@hooli.com"])
  owners.each do |user|
    QuoteOwner.create!(
      quote: quote,
      user: user,
      organization: organization
    )
  end
  Quote.transaction do
    (1..versions_count).each do |version|
      last_version = version == versions_count
      quote_version = create_quote_version(
        quote:,
        status: (last_version ? :draft : :voided),
        void_reason: (last_version ? nil : :manual),
        voided_at: (last_version ? nil : Time.current)
      )
      quote.update!(current_version: quote_version) if last_version
    end
  end
end

# Add a draft quote per each customer
def create_draft_quote_for_each_customer(organization:)
  (1..5).each do |i|
    customer = Customer.find_by!(external_id: "cust_#{i}")
    quote = create_quote(
      organization: organization,
      customer: customer,
      order_type: :one_off
    )
    quote_version = create_quote_version(quote: quote)
    quote.update!(current_version: quote_version)
  end
end

# Create a standalone approved quote with an order form. Order forms only exist
# on approved quote_versions, so we build a fresh quote/version dedicated to
# them — without touching the draft quotes seeded above, which may be relied on
# by other QA flows.
def create_approved_quote_with_order_form(organization:, customer:, status: :generated, expires_at: nil)
  quote = create_quote(
    organization: organization,
    customer: customer,
    order_type: :one_off
  )
  quote_version = create_quote_version(
    quote: quote,
    status: :approved,
    approved_at: Time.current
  )
  quote.update!(current_version: quote_version)
  create_order_form(
    quote_version: quote_version,
    status: status,
    expires_at: expires_at
  )
end

create_quote_chain(organization: @organization, customer: @customer)
create_draft_quote_for_each_customer(organization: @organization)

[
  {customer_external_id: "cust_john-doe", status: :generated},
  {customer_external_id: "cust_1", status: :generated},
  {customer_external_id: "cust_2", status: :signed},
  {customer_external_id: "cust_3", status: :expired},
  {customer_external_id: "cust_4", status: :voided},
  {customer_external_id: "cust_5", status: :generated, expires_at: 7.days.from_now}
].each do |params|
  customer = Customer.find_by!(external_id: params.delete(:customer_external_id))
  create_approved_quote_with_order_form(organization: @organization, customer: customer, **params)
end
