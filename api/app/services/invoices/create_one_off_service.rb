# frozen_string_literal: true

module Invoices
  class CreateOneOffService < BaseService
    Result = BaseResult[:invoice, :payment_method]

    def initialize(customer:, currency:, fees:, timestamp:, skip_psp: false, voided_invoice_id: nil, payment_method_params: nil, invoice_custom_section: {}, billing_entity_id: nil, billing_entity_code: nil, purchase_order_number: nil)
      @customer = customer
      @currency = currency || customer&.currency
      @fees = fees
      @timestamp = timestamp
      @skip_psp = skip_psp || false
      @voided_invoice_id = voided_invoice_id
      @payment_method_params = payment_method_params
      @invoice_custom_section = invoice_custom_section
      @billing_entity_id = billing_entity_id
      @billing_entity_code = billing_entity_code
      @purchase_order_number = purchase_order_number

      super(nil)
    end

    activity_loggable(
      action: "invoice.one_off_created",
      record: -> { result.invoice },
      condition: -> { result.invoice&.finalized? }
    )

    def call
      return result.not_found_failure!(resource: "customer") unless customer
      return result.not_found_failure!(resource: "fees") if fees.blank?
      return result.not_found_failure!(resource: "add_on") unless add_ons.count == add_on_identifiers.count
      return result unless valid_payment_method?

      resolve_billing_entity
      return result unless result.success?

      tax_deferred = false

      ActiveRecord::Base.transaction do
        Customers::UpdateCurrencyService
          .call(customer:, currency:)
          .raise_if_error!

        create_generating_invoice

        result.invoice = invoice

        create_one_off_fees(invoice)

        invoice.fees_amount_cents = invoice.fees.sum(:amount_cents)
        invoice.sub_total_excluding_taxes_amount_cents = invoice.fees_amount_cents

        invoice.payment_method = payment_method
        invoice.skip_automatic_payment = skip_psp

        # NOTE: Custom sections are applied before computing taxes so they are persisted even when
        #       tax computation is deferred to a tax provider (the `next` below skips the rest of the block).
        unless skip_custom_sections?
          Invoices::ApplyInvoiceCustomSectionsService.call(invoice:, custom_section_ids: invoice_custom_section_ids)
        end

        totals_result = Invoices::ComputeTaxesAndTotalsService.call(invoice:)
        if totals_result.failure? && totals_result.error.is_a?(BaseService::UnknownTaxFailure)
          tax_deferred = true
          next
        end
        totals_result.raise_if_error!

        invoice.payment_status = invoice.total_amount_cents.positive? ? :pending : :succeeded
        Invoices::TransitionToFinalStatusService.call(invoice:)
        invoice.voided_invoice_id = voided_invoice_id if voided_invoice_id.present?
        invoice.save!
      end

      return result if tax_deferred

      unless invoice.closed?
        Utils::SegmentTrack.invoice_created(invoice)
        SendWebhookJob.perform_later("invoice.one_off_created", invoice)
        GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
        Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
        Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
        Invoices::Payments::CreateService.call_async(invoice:, payment_method_params:) unless invoice.skip_automatic_payment?
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue Sequenced::SequenceError
      raise
    rescue BaseService::FailedResult => e
      e.result
    rescue => e
      result.fail_with_error!(e)
    end

    private

    attr_accessor :timestamp, :currency, :customer, :fees, :invoice, :skip_psp, :voided_invoice_id, :payment_method_params, :invoice_custom_section
    attr_reader :billing_entity_id, :billing_entity_code, :billing_entity, :purchase_order_number

    def create_generating_invoice
      invoice_result = Invoices::CreateGeneratingService.call(
        customer:,
        invoice_type: :one_off,
        currency:,
        datetime: Time.zone.at(timestamp),
        billing_entity:
      )
      invoice_result.raise_if_error!

      @invoice = invoice_result.invoice
      # NOTE: Persisted immediately so the value survives the tax-deferred path,
      #       which skips the later `invoice.save!`.
      @invoice.update!(purchase_order_number:) unless purchase_order_number.nil?
    end

    def resolve_billing_entity
      if multi_entity_enabled? && billing_entity_id.present?
        @billing_entity = customer.organization.billing_entities.find_by(id: billing_entity_id)
        result.not_found_failure!(resource: "billing_entity") if @billing_entity.nil?
      elsif multi_entity_enabled? && billing_entity_code.present?
        @billing_entity = customer.organization.billing_entities.find_by(code: billing_entity_code)
        result.not_found_failure!(resource: "billing_entity") if @billing_entity.nil?
      else
        @billing_entity = customer.billing_entity
      end
    end

    def multi_entity_enabled?
      customer.organization.feature_flag_enabled?(:multi_entity_billing)
    end

    def create_one_off_fees(invoice)
      Fees::OneOffService.call!(invoice:, fees:)
    end

    def should_deliver_email?
      License.premium? && invoice.billing_entity.email_settings.include?("invoice.finalized")
    end

    def add_ons
      finder = api_context? ? :code : :id

      customer.organization.add_ons.where(finder => add_on_identifiers)
    end

    def add_on_identifiers
      identifier = api_context? ? :add_on_code : :add_on_id

      fees.pluck(identifier).uniq
    end

    def valid_payment_method?
      result.payment_method = payment_method

      PaymentMethods::ValidateService.new(result, payment_method: payment_method_params).valid?
    end

    def payment_method
      return @payment_method if defined? @payment_method
      return nil if payment_method_params.blank? || payment_method_params[:payment_method_id].blank?

      @payment_method = customer.payment_methods.find_by(id: payment_method_params[:payment_method_id])
    end

    def invoice_custom_section_ids
      return @invoice_custom_section_ids if defined?(@invoice_custom_section_ids)
      return @invoice_custom_section_ids = [] if section_identifiers.blank?

      identifier = api_context? ? :code : :id
      @invoice_custom_section_ids =
        customer.organization.invoice_custom_sections.where(identifier => section_identifiers).pluck(:id)
    end

    def section_identifiers
      return nil unless invoice_custom_section

      key = api_context? ? :invoice_custom_section_codes : :invoice_custom_section_ids

      invoice_custom_section[key]&.compact&.uniq
    end

    def skip_custom_sections?
      return false unless invoice_custom_section
      return false if invoice_custom_section[:skip_invoice_custom_sections].nil?

      invoice_custom_section[:skip_invoice_custom_sections]
    end
  end
end
