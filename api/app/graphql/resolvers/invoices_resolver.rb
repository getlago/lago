# frozen_string_literal: true

module Resolvers
  class InvoicesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "invoices:view"

    description "Query invoices"

    argument :amount_from, Integer, required: false
    argument :amount_to, Integer, required: false
    argument :billing_entity_ids, [ID], required: false
    argument :currency, Types::CurrencyEnum, required: false
    argument :customer_external_id, String, required: false
    argument :customer_id, ID, required: false, description: "Uniq ID of the customer"
    argument :invoice_type, [Types::Invoices::InvoiceTypeEnum], required: false
    argument :issuing_date_from, GraphQL::Types::ISO8601Date, required: false
    argument :issuing_date_to, GraphQL::Types::ISO8601Date, required: false
    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :partially_paid, Boolean, required: false
    argument :payment_dispute_lost, Boolean, required: false
    argument :payment_overdue, Boolean, required: false
    argument :payment_status, [Types::Invoices::PaymentStatusTypeEnum], required: false
    argument :positive_due_amount, Boolean, required: false
    argument :search_term, String, required: false
    argument :self_billed, Boolean, required: false
    argument :settlements, [Types::Invoices::SettlementTypeEnum], required: false
    argument :status, [Types::Invoices::StatusTypeEnum], required: false
    argument :subscription_id, ID, required: false

    type Types::Invoices::Object.collection_type, null: false

    def resolve( # rubocop:disable Metrics/ParameterLists
      amount_from: nil,
      amount_to: nil,
      billing_entity_ids: nil,
      currency: nil,
      customer_external_id: nil,
      customer_id: nil,
      invoice_type: nil,
      issuing_date_from: nil,
      issuing_date_to: nil,
      limit: nil,
      page: nil,
      payment_dispute_lost: nil,
      payment_overdue: nil,
      partially_paid: nil,
      positive_due_amount: nil,
      payment_status: nil,
      search_term: nil,
      self_billed: nil,
      status: nil,
      settlements: nil,
      subscription_id: nil
    )
      result = InvoicesQuery.call(
        organization: current_organization,
        pagination: {page:, limit:},
        search_term:,
        filters: {
          amount_from:,
          amount_to:,
          billing_entity_ids:,
          currency:,
          customer_external_id:,
          customer_id:,
          invoice_type:,
          issuing_date_from:,
          issuing_date_to:,
          partially_paid:,
          payment_dispute_lost:,
          payment_overdue:,
          payment_status:,
          positive_due_amount:,
          self_billed:,
          status:,
          settlements:,
          subscription_id:
        }
      )

      return result_error(result) unless result.success?

      Invoice.preload_offset_amounts(
        result.invoices.preload(
          :fees,
          :regenerated_invoice,
          :error_details,
          :billing_entity,
          :customer_payments,
          {customer: :billing_entity}
        )
      )
    end
  end
end
