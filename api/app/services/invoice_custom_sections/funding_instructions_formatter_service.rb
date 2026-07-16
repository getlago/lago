# frozen_string_literal: true

module InvoiceCustomSections
  class FundingInstructionsFormatterService < BaseService
    Result = BaseResult[:details]

    def initialize(funding_data:, locale:)
      @funding_data = funding_data
      @locale = locale
      super
    end

    def call
      I18n.with_locale(locale) do
        lines = []
        t = ->(key) { I18n.t("invoice.#{key}") }

        lines << t.call(:bank_transfer_info)
        lines << ""

        case funding_data[:type]
        when "us_bank_transfer" then format_us_bank_transfer(lines, t)
        when "mx_bank_transfer" then lines << format_mx_bank_transfer(t)
        when "jp_bank_transfer" then lines << format_jp_bank_transfer(t)
        when "gb_bank_transfer" then lines << format_gb_bank_transfer(t)
        when "eu_bank_transfer" then lines << format_eu_bank_transfer(t)
        else
          result.service_failure!(
            code: "unsupported_funding_type",
            message: "Funding type '#{funding_data[:type]}' is not supported"
          )
        end

        result.details = lines.join("\n")
        result
      end
    end

    private

    attr_reader :funding_data, :locale

    def format_us_bank_transfer(lines, t)
      addresses = funding_data[:financial_addresses] || []

      addresses.each do |address|
        type = address[:type]&.to_sym
        details = address[type] || {}

        block = case type
        when :aba
          <<~TEXT
            US ACH, Domestic Wire
            #{t.call(:bank_name)}: #{details_or_default(details[:bank_name])}
            #{t.call(:account_number)}: #{details_or_default(details[:account_number])}
            #{t.call(:routing_number)}: #{details_or_default(details[:routing_number])}
          TEXT
        when :swift
          <<~TEXT
            SWIFT
            #{t.call(:bank_name)}: #{details_or_default(details[:bank_name])}
            #{t.call(:account_number)}: #{details_or_default(details[:account_number])}
            #{t.call(:swift_code)}: #{details_or_default(details[:swift_code])}
          TEXT
        end

        lines << block.strip if block
        lines << "" if block
      end
    end

    def format_mx_bank_transfer(t)
      details = extract_details(:mx_bank_transfer)
      <<~TEXT.strip
        #{t.call(:clabe)}: #{details_or_default(details[:clabe])}
        #{t.call(:bank_name)}: #{details_or_default(details[:bank_name])}
        #{t.call(:bank_code)}: #{details_or_default(details[:bank_code])}
      TEXT
    end

    def format_jp_bank_transfer(t)
      details = extract_details(:jp_bank_transfer)
      <<~TEXT.strip
        #{t.call(:bank_code)}: #{details_or_default(details[:bank_code])}
        #{t.call(:bank_name)}: #{details_or_default(details[:bank_name])}
        #{t.call(:branch_code)}: #{details_or_default(details[:branch_code])}
        #{t.call(:branch_name)}: #{details_or_default(details[:branch_name])}
        #{t.call(:account_type)}: #{details_or_default(details[:account_type])}
        #{t.call(:account_number)}: #{details_or_default(details[:account_number])}
        #{t.call(:account_holder_name)}: #{details_or_default(details[:account_holder_name])}
      TEXT
    end

    def format_gb_bank_transfer(t)
      details = extract_details(:sort_code)
      <<~TEXT.strip
        #{t.call(:account_number)}: #{details_or_default(details[:account_number])}
        #{t.call(:sort_code)}: #{details_or_default(details[:sort_code])}
        #{t.call(:account_holder_name)}: #{details_or_default(details[:account_holder_name])}
      TEXT
    end

    def format_eu_bank_transfer(t)
      details = extract_details(:iban)
      <<~TEXT.strip
        #{t.call(:bic)}: #{details_or_default(details[:bic])}
        #{t.call(:iban)}: #{details_or_default(details[:iban])}
        #{t.call(:country)}: #{details_or_default(details[:country])}
        #{t.call(:account_holder_name)}: #{details_or_default(details[:account_holder_name])}
      TEXT
    end

    def extract_details(key)
      funding_data[:financial_addresses]&.first&.dig(key) || {}
    end

    def details_or_default(value)
      value.presence || "-"
    end
  end
end
