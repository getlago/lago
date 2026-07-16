# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::ViesCheckService do
  subject(:vies_check_service) { described_class.new(customer:) }

  let(:organization) { create(:organization, country: "IT", eu_tax_management: true) }
  let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: true) }
  let(:customer) { create(:customer, organization:, billing_entity:, tax_identification_number:, zipcode: nil, country: "DE") }
  let(:tax_identification_number) { "IT12345678901" }

  shared_examples "a VIES check error" do |error_type:, fault_string: nil, http_status: 200|
    raise "Please provide either fault_string or a http_status that is not 200" if fault_string.nil? && http_status == 200

    let(:full_error_message) { "The VIES web service returned the error: #{fault_string || http_status}" }

    before do
      body = if http_status == 200
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><env:Envelope xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\"><env:Body><env:Fault><faultcode>env:Server</faultcode><faultstring>#{fault_string || full_error_message}</faultstring></env:Fault></env:Body></env:Envelope>"
      else
        "ERROR"
      end
      stub_request(:post, "https://ec.europa.eu/taxation_customs/vies/services/checkVatService")
        .to_return(status: http_status, body: body)
    end

    it "returns an error" do
      result = vies_check_service.call

      expect(result).not_to be_success
      expect(result.tax_code).to be_nil
      expect(result.error.code).to eq("vies_check_failed")
      expect(result.error.message).to eq("vies_check_failed: #{full_error_message}")
    end

    it "sends a vies_check webhook with error details" do
      expect { vies_check_service.call }
        .to have_enqueued_job(SendWebhookJob)
        .with("customer.vies_check", customer, vies_check: {valid: false, valid_format: true, error: full_error_message})
    end

    it "creates a pending_vies_check record" do
      expect { vies_check_service.call }.to change(PendingViesCheck, :count).by(1)

      pending_check = customer.pending_vies_check
      expect(pending_check).to have_attributes(
        organization: customer.organization,
        billing_entity: customer.billing_entity,
        tax_identification_number: customer.tax_identification_number,
        attempts_count: 1,
        last_error_type: error_type,
        last_error_message: full_error_message
      )
      expect(pending_check.last_attempt_at).to be_present
    end

    it "returns the pending_vies_check in the result" do
      result = vies_check_service.call

      expect(result.pending_vies_check).to be_present
      expect(result.pending_vies_check.attempts_count).to eq(1)
    end

    context "when pending_vies_check already exists" do
      let(:existing_check) { create(:pending_vies_check, customer:, attempts_count: 2, last_error_type: "unknown") }

      before { existing_check }

      it "updates the existing record and increments attempts_count" do
        expect { vies_check_service.call }.not_to change(PendingViesCheck, :count)

        existing_check.reload
        expect(existing_check.attempts_count).to eq(3)
        expect(existing_check.last_error_type).to eq(error_type)
      end
    end
  end

  describe ".call" do
    let(:vies_response) { {} }

    context "when VIES check is successful" do
      before do
        allow_any_instance_of(Valvat).to receive(:exists?).and_return(vies_response) # rubocop:disable RSpec/AnyInstance
      end

      context "when eu_tax_management is disabled" do
        let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: false) }
        let(:vies_response) { nil }

        it "returns not_allowed_failure" do
          result = vies_check_service.call

          expect(result).not_to be_success
          expect(result.error.code).to eq("eu_tax_not_applicable")
        end
      end

      context "when vat number is invalid" do
        let(:tax_identification_number) { "invalid_vat_number" }
        let(:vies_response) { false }

        before do
          allow_any_instance_of(Valvat).to receive(:exists?).and_call_original # rubocop:disable RSpec/AnyInstance
        end

        it "returns the customer country tax code and vies_check details" do
          result = vies_check_service.call

          expect(result.tax_code).to eq("lago_eu_de_standard")
          expect(result.vies_check).to eq({valid: false, valid_format: false})
        end

        it "sends a vies_check webhook with error details" do
          expect { vies_check_service.call }
            .to have_enqueued_job(SendWebhookJob)
            .with("customer.vies_check", customer, vies_check: {valid: false, valid_format: false})
        end
      end

      context "with same country as the billing_entity" do
        let(:vies_response) { {country_code: "FR"} }

        it "returns the organization country tax code" do
          result = vies_check_service.call

          expect(result.tax_code).to eq("lago_eu_fr_standard")
        end

        it "returns the vies_check response" do
          result = vies_check_service.call

          expect(result.vies_check).to eq(vies_response)
        end

        it "sends a vies_check webhook" do
          expect { vies_check_service.call }
            .to have_enqueued_job(SendWebhookJob)
            .with("customer.vies_check", customer, vies_check: vies_response)
        end

        context "when a pending_vies_check exists from a previous failure" do
          let(:pending_check) { create(:pending_vies_check, customer:) }

          before { pending_check }

          it "deletes the pending_vies_check record" do
            expect { vies_check_service.call }.to change(PendingViesCheck, :count).by(-1)
            expect(customer.reload.pending_vies_check).to be_nil
          end
        end
      end

      context "with a different country from the billing_entity one" do
        let(:vies_response) { {country_code: "DE"} }

        it "returns the reverse charge tax" do
          result = vies_check_service.call

          expect(result.tax_code).to eq("lago_eu_reverse_charge")
        end
      end

      context "when country has exceptions" do
        let(:vies_response) { {country_code: "FR"} }

        context "when customer has no zipcode" do
          it "returns the customer country standard tax" do
            result = vies_check_service.call
            expect(result.tax_code).to eq("lago_eu_fr_standard")
          end
        end

        context "when customer has a zipcode" do
          context "when zipcode has applicable exceptions" do
            before { customer.update(country: "FR", zipcode: "97412") }

            it "returns the exception tax code" do
              result = vies_check_service.call
              expect(result.tax_code).to eq("lago_eu_fr_exception_reunion")
            end
          end

          context "when zipcode has no applicable exceptions" do
            before { customer.update(country: "FR", zipcode: "12345") }

            it "returns the customer counrty standard tax" do
              result = vies_check_service.call
              expect(result.tax_code).to eq("lago_eu_fr_standard")
            end
          end
        end
      end

      context "when VIES returns nil (TIN present but Valvat returns nil/falsy)" do
        let(:vies_response) { false }

        context "when the customer has no country" do
          before { customer.update(country: nil) }

          it "returns the billing entity country tax code" do
            result = vies_check_service.call

            expect(result.tax_code).to eq("lago_eu_fr_standard")
          end
        end

        context "when the customer country is in europe" do
          it "returns the customer country tax code" do
            result = vies_check_service.call

            expect(result.tax_code).to eq("lago_eu_de_standard")
          end
        end

        context "when the customer country is out of europe" do
          before { customer.update(country: "US") }

          it "returns the tax exempt tax code" do
            result = vies_check_service.call

            expect(result.tax_code).to eq("lago_eu_tax_exempt")
          end
        end
      end
    end

    {
      "MS_MAX_CONCURRENT_REQ" => "rate_limit",
      "MS_UNAVAILABLE" => "member_state_unavailable",
      "SERVICE_UNAVAILABLE" => "service_unavailable",
      "TIMEOUT" => "timeout",
      "VAT_BLOCKED" => "blocked",
      "INVALID_REQUESTER_INFO" => "invalid_requester"
    }.each do |fault_string, error_type|
      context "when VIES check raises #{error_type} error" do
        it_behaves_like "a VIES check error",
          fault_string:,
          error_type:
      end
    end

    [
      307,
      400,
      500
    ].each do |http_status|
      context "when VIES check raises HTTPError with #{http_status}" do
        it_behaves_like "a VIES check error",
          http_status: http_status,
          error_type: "service_unavailable"
      end
    end
  end
end
