# frozen_string_literal: true

RSpec.shared_examples "a result object" do
  it { expect(result).to be_success }
  it { expect(result).not_to be_failure }
  it { expect(result.error).to be_nil }

  it { expect(result.raise_if_error!).to eq(result) }

  describe ".fail_with_error!" do
    let(:error) { StandardError.new("custom_error") }

    it "assign the error the result" do
      failure = result.fail_with_error!(error)

      expect(failure).to eq(result)
      expect(result).not_to be_success
      expect(result).to be_failure
      expect(result.error).to eq(error)
    end
  end

  describe ".forbidden_failure!" do
    before { result.forbidden_failure! }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ForbiddenFailure) }
    it { expect(result.error.code).to eq("feature_unavailable") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::ForbiddenFailure) }

    context "when passing a code to the failure" do
      before { result.forbidden_failure!(code: "custom_code") }

      it { expect(result.error.code).to eq("custom_code") }
    end
  end

  describe ".not_allowed_failure!" do
    before { result.not_allowed_failure!(code: "custom_code") }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::MethodNotAllowedFailure) }
    it { expect(result.error.code).to eq("custom_code") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::MethodNotAllowedFailure) }
  end

  describe ".not_found_failure!" do
    before { result.not_found_failure!(resource: "custom_resource") }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::NotFoundFailure) }
    it { expect(result.error.error_code).to eq("custom_resource_not_found") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::NotFoundFailure) }
  end

  describe ".service_failure!" do
    before { result.service_failure!(code: "custom_code", message: "custom_message") }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ServiceFailure) }
    it { expect(result.error.code).to eq("custom_code") }
    it { expect(result.error.message).to eq("custom_code: custom_message") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::ServiceFailure) }
  end

  describe ".unauthorized_failure!" do
    before { result.unauthorized_failure! }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::UnauthorizedFailure) }
    it { expect(result.error.message).to eq("unauthorized") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::UnauthorizedFailure) }

    context "when passing a code to the failure" do
      before { result.unauthorized_failure!(message: "custom_code") }

      it { expect(result.error.message).to eq("custom_code") }
    end
  end

  describe ".validation_failure!" do
    before { result.validation_failure!(errors: {field: ["error"]}) }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ValidationFailure) }
    it { expect(result.error.messages).to eq({field: ["error"]}) }
    it { expect(result.error.message).to eq('Validation errors: {"field":["error"]}') }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::ValidationFailure) }
  end

  describe ".record_validation_failure!" do
    let(:record) { Customer.new.tap(&:valid?) }

    before { result.record_validation_failure!(record:) }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ValidationFailure) }
    it { expect(result.error.messages.keys).to match_array(%i[external_id organization]) }
    it { expect(result.error.message).to eq("Validation errors: #{result.error.messages.to_json}") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::ValidationFailure) }
  end

  describe ".single_validation_failure!" do
    before { result.single_validation_failure!(error_code: "error_code") }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ValidationFailure) }
    it { expect(result.error.messages).to eq({base: ["error_code"]}) }
    it { expect(result.error.message).to eq('Validation errors: {"base":["error_code"]}') }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::ValidationFailure) }

    context "when passing a field to the failure" do
      before { result.single_validation_failure!(error_code: "error", field: "field") }

      it { expect(result.error.messages).to eq({field: ["error"]}) }
      it { expect(result.error.message).to eq('Validation errors: {"field":["error"]}') }
    end
  end

  describe ".unknown_tax_failure!" do
    before { result.unknown_tax_failure!(code: "custom_code", message: "custom_message") }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::UnknownTaxFailure) }
    it { expect(result.error.code).to eq("custom_code") }
    it { expect(result.error.message).to eq("custom_code: custom_message") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::UnknownTaxFailure) }
  end

  describe ".third_party_failure!" do
    before { result.third_party_failure!(third_party: "stripe", error_code: "code", error_message: "custom_message") }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ThirdPartyFailure) }
    it { expect(result.error.third_party).to eq("stripe") }
    it { expect(result.error.message).to eq("stripe: code - custom_message") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::ThirdPartyFailure) }
  end

  describe ".too_many_provider_requests_failure!" do
    let(:error) { StandardError.new("custom_error") }
    let(:provider_name) { "anrok" }

    before { result.too_many_provider_requests_failure!(provider_name:, error:) }

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::TooManyProviderRequestsFailure) }
    it { expect(result.error.message).to eq("custom_error") }
    it { expect(result.error.provider_name).to eq("anrok") }

    it { expect { result.raise_if_error! }.to raise_error(BaseService::TooManyProviderRequestsFailure) }
  end

  describe ".raise_if_error!" do
    context "when the result is a failure" do
      before { result.fail_with_error!(StandardError.new) }

      it { expect { result.raise_if_error! }.to raise_error(StandardError) }
    end

    context "when the result is a success" do
      it { expect(result.raise_if_error!).to eq(result) }
    end
  end
end
