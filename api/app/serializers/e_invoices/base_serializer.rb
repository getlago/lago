# frozen_string_literal: true

module EInvoices
  class BaseSerializer
    # More document types defined on UNCL 1001 here
    # https://service.unece.org/trade/untdid/d99a/uncl/uncl1001.htm
    PAYMENT_RECEIPT = 202
    COMMERCIAL_INVOICE = 380
    CREDIT_NOTE = 381
    PREPAID_INVOICE = 386
    SELF_BILLED_INVOICE = 389

    # More taxations defined on UNTDID 5153 here
    # https://service.unece.org/trade/untdid/d00a/tred/tred5153.htm
    VAT = "VAT"

    # More VAT exemptions codes
    # https://docs.peppol.eu/poacc/billing/3.0/codelist/vatex/
    O_VAT_EXEMPTION = "VATEX-EU-O"

    # You can see more payments codes UNTDID 4461 here
    # https://service.unece.org/trade/untdid/d21b/tred/tred4461.htm
    STANDARD_PAYMENT = 1
    CREDIT_CARD_PAYMENT = 48
    PREPAID_PAYMENT = 57
    CREDIT_NOTE_PAYMENT = 97

    INVOICE_DISCOUNT = false
    INVOICE_CHARGE = true

    # More categories for UNTDID 5305 here
    # https://service.unece.org/trade/untdid/d00a/tred/tred5305.htm
    S_CATEGORY = "S"
    O_CATEGORY = "O"
    Z_CATEGORY = "Z"

    # More measures codes defined in UNECE Recommendation 20 here
    # https://docs.peppol.eu/pracc/catalogue/1.0/codelist/UNECERec20/
    UNIT_CODE = "C62"

    # Response codes for Payments
    # There are no strict codes for this
    ACKNOWLEDGEMENT = "AC"
    PENDING = "PE"
    REJECTED = "RE"
    PAID = "PD"

    def initialize(xml:, resource: nil)
      @xml = xml
      @resource = resource
    end

    def self.serialize(*, **, &)
      new(*, **).serialize(&)
    end

    private

    attr_accessor :xml, :resource

    def formatted_date(date)
      date.strftime(self.class::DATEFORMAT)
    end

    def invoice_type_code(invoice)
      if invoice.credit?
        EInvoices::BaseSerializer::PREPAID_INVOICE
      elsif invoice.self_billed?
        EInvoices::BaseSerializer::SELF_BILLED_INVOICE
      else
        EInvoices::BaseSerializer::COMMERCIAL_INVOICE
      end
    end

    def payment_information(type, amount)
      case type
      when STANDARD_PAYMENT
        payment_label(type)
      when PREPAID_PAYMENT, CREDIT_NOTE_PAYMENT
        I18n.t("invoice.e_invoicing.payment_information", payment_label: payment_label(type), currency: resource.currency, amount:)
      when CREDIT_CARD_PAYMENT
        I18n.t("invoice.e_invoicing.credit_card_information", date: resource.created_at)
      end
    end

    def payment_label(type)
      case type
      when STANDARD_PAYMENT
        I18n.t("invoice.e_invoicing.standard_payment")
      when PREPAID_PAYMENT
        I18n.t("invoice.prepaid_credits")
      when CREDIT_NOTE_PAYMENT
        I18n.t("invoice.credit_notes")
      when CREDIT_CARD_PAYMENT
        I18n.t("invoice.e_invoicing.credit_card")
      end
    end

    def discount_reason
      I18n.t("invoice.e_invoicing.discount_reason", tax_rate: percent(tax_rate))
    end

    def tax_category_code(tax_rate:, type: nil)
      return O_CATEGORY if type == "credit"

      tax_rate.zero? ? Z_CATEGORY : S_CATEGORY
    end

    def allowance_charges(&block)
      allowances_per_tax_rate.each_pair do |tax_rate, amount|
        next if amount.zero?

        yield tax_rate, Money.new(amount)
      end
    end

    def line_items(items, &block)
      resource.send(items).order(amount_cents: :asc).each_with_index do |item, index|
        yield item, index + 1
      end
    end

    def fee_description(fee)
      return fee.invoice_name if fee.invoice_name.present?

      I18n.t(
        "invoice.subscription_interval",
        plan_interval: I18n.t("invoice.#{fee.subscription.plan.interval}"),
        plan_name: fee.subscription.plan.invoice_name
      )
    end

    def percent(value)
      format_number(value, "%.2f%%")
    end

    def format_number(value, mask = "%.2f")
      format(mask, value)
    end
  end
end
