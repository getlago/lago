# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSections::FundingInstructionsFormatterService do
  describe "#call" do
    subject(:result) { service.call }

    let(:service) { described_class.new(funding_data: funding_data, locale: :en) }

    shared_examples "includes bank transfer info intro" do
      it "includes the bank transfer info header" do
        expect(result.details).to start_with("Bank transfers may take several business days to process. To pay via bank transfer, transfer funds using the following bank information.")
      end
    end

    context "when funding type is us_bank_transfer" do
      let(:funding_data) do
        {
          type: "us_bank_transfer",
          financial_addresses: [
            {
              type: "aba",
              aba: {
                account_holder_name: "Teste",
                account_number: "11119987600453127",
                bank_name: "US Test Bank",
                routing_number: "999999999"
              }
            },
            {
              type: "swift",
              swift: {
                account_holder_name: "Teste",
                account_number: "11119987600453127",
                bank_name: "US Test Bank",
                swift_code: "TESTUS99XXX"
              }
            }
          ]
        }
      end

      include_examples "includes bank transfer info intro"
      it "formats ABA and SWIFT details correctly with headers" do
        aba_section = <<~TEXT.strip
          US ACH, Domestic Wire
          Bank name: US Test Bank
          Account number: 11119987600453127
          Routing number: 999999999
        TEXT

        swift_section = <<~TEXT.strip
          SWIFT
          Bank name: US Test Bank
          Account number: 11119987600453127
          SWIFT code: TESTUS99XXX
        TEXT

        expect(result.details).to include(aba_section)
        expect(result.details).to include(swift_section)
      end
    end

    context "when funding type is eu_bank_transfer" do
      let(:funding_data) do
        {
          type: "eu_bank_transfer",
          financial_addresses: [
            {
              type: "iban",
              iban: {
                account_holder_name: "Teste",
                bic: "AGRIFRPPXXX",
                country: "FR",
                iban: "FR61284383901570478105144165"
              }
            }
          ]
        }
      end

      include_examples "includes bank transfer info intro"
      it "formats IBAN details correctly" do
        expect(result.details).to include("BIC: AGRIFRPPXXX")
        expect(result.details).to include("IBAN: FR61284383901570478105144165")
        expect(result.details).to include("Country: FR")
        expect(result.details).to include("Account holder name: Teste")
      end
    end

    context "when funding type is mx_bank_transfer" do
      let(:funding_data) do
        {
          type: "mx_bank_transfer",
          financial_addresses: [
            {
              mx_bank_transfer: {
                clabe: "002010077777777771",
                bank_name: "Banco MX",
                bank_code: "002"
              }
            }
          ]
        }
      end

      include_examples "includes bank transfer info intro"
      it "includes CLABE transfer details" do
        expect(result.details).to include("CLABE: 002010077777777771")
        expect(result.details).to include("Bank name: Banco MX")
        expect(result.details).to include("Bank code: 002")
      end
    end

    context "when funding type is jp_bank_transfer" do
      let(:funding_data) do
        {
          type: "jp_bank_transfer",
          financial_addresses: [
            {
              jp_bank_transfer: {
                bank_code: "0005",
                bank_name: "JP Test Bank",
                branch_code: "001",
                branch_name: "Tokyo",
                account_type: "type_test",
                account_number: "1234567",
                account_holder_name: "name_account"
              }
            }
          ]
        }
      end

      include_examples "includes bank transfer info intro"
      it "includes Japanese bank transfer details" do
        expect(result.details).to include("Bank code: 0005")
        expect(result.details).to include("Bank name: JP Test Bank")
        expect(result.details).to include("Branch code: 001")
        expect(result.details).to include("Branch name: Tokyo")
        expect(result.details).to include("Account type: type_test")
        expect(result.details).to include("Account number: 1234567")
        expect(result.details).to include("Account holder name: name_account")
      end
    end

    context "when funding type is gb_bank_transfer" do
      let(:funding_data) do
        {
          type: "gb_bank_transfer",
          financial_addresses: [
            {
              sort_code: {
                account_number: "12345678",
                sort_code: "12-34-56",
                account_holder_name: "Test UK"
              }
            }
          ]
        }
      end

      include_examples "includes bank transfer info intro"
      it "includes GB sort code transfer details" do
        expect(result.details).to include("Account number: 12345678")
        expect(result.details).to include("Sort code: 12-34-56")
        expect(result.details).to include("Account holder name: Test UK")
      end
    end
  end
end
