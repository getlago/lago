# frozen_string_literal: true

RSpec.describe ExecutionErrorResponder do
  let(:responder) { klass.new }

  let(:klass) do
    Class.new do
      include ExecutionErrorResponder

      public :execution_error, :not_found_error, :not_allowed_error, :forbidden_error, :validation_error,
        :third_party_failure, :result_error
    end
  end

  describe "execution_error" do
    subject(:error) do
      responder.execution_error(error: "Custom error", status: 400, code: "custom_code", details: {foo_bar: "baz"})
    end

    let(:extensions) do
      {status: 400, code: "custom_code", details: {"fooBar" => "baz"}}
    end

    it "returns a GraphQL::ExecutionError with correct message and extensions" do
      expect(subject).to be_a(GraphQL::ExecutionError)
      expect(subject.message).to eq("Custom error")
      expect(subject.extensions).to eq(extensions)
    end

    it "omits details if not a Hash" do
      error = responder.execution_error(details: "not a hash")
      expect(error.extensions).not_to have_key(:details)
    end
  end

  describe "not_found_error" do
    subject(:error) { responder.not_found_error(resource: :alert) }

    let(:extensions) do
      {status: 404, code: "not_found", details: {"alert" => ["not_found"]}}
    end

    it "returns a 404 not found error with resource details" do
      expect(subject.extensions).to eq(extensions)
    end
  end

  describe "not_allowed_error" do
    subject(:error) { responder.not_allowed_error(code: "method_not_allowed") }

    let(:extensions) do
      {status: 405, code: "method_not_allowed"}
    end

    it "returns a 405 not allowed error with code" do
      expect(subject.extensions).to eq(extensions)
    end
  end

  describe "forbidden_error" do
    subject(:error) { responder.forbidden_error(code: "access_denied") }

    let(:extensions) do
      {status: 403, code: "access_denied"}
    end

    it "returns a 403 forbidden error with code" do
      expect(subject.extensions).to eq(extensions)
    end
  end

  describe "validation_error" do
    subject(:error) { responder.validation_error(messages: {name: ["can't be blank"]}) }

    let(:extensions) do
      {status: 422, code: "unprocessable_entity", details: {"name" => ["can't be blank"]}}
    end

    it "returns a 422 validation error with messages" do
      expect(subject.extensions).to eq(extensions)
    end
  end

  describe "#third_party_failure" do
    subject(:error) { responder.third_party_failure(messages: "External service failed") }

    let(:extensions) do
      {status: 422, code: "third_party_error", details: {"error" => "External service failed"}}
    end

    it "returns a 422 third party error with messages" do
      expect(subject.extensions).to eq(extensions)
    end
  end

  describe "#result_error" do
    subject(:result_error) { responder.result_error(result) }

    let(:result) { BaseResult.new }

    before { result.fail_with_error!(error) }

    context "when the service result is a NotFoundFailure" do
      let(:error) { BaseService::NotFoundFailure.new(result, resource: :alert) }

      it "returns a not found error" do
        expect(subject).to be_a(GraphQL::ExecutionError)
        expect(subject.extensions).to include(status: 404, code: "not_found")
      end
    end

    context "when the service result is a MethodNotAllowedFailure" do
      let(:error) { BaseService::MethodNotAllowedFailure.new(result, code: "method_not_allowed") }

      it "returns a not allowed error" do
        expect(subject).to be_a(GraphQL::ExecutionError)
        expect(subject.extensions).to include(status: 405, code: "method_not_allowed")
      end
    end

    context "when the service result is a ValidationFailure" do
      let(:error) { BaseService::ValidationFailure.new(result, messages: {name: ["can't be blank"]}) }

      it "returns a validation error" do
        expect(subject).to be_a(GraphQL::ExecutionError)
        expect(subject.extensions).to include(status: 422, code: "unprocessable_entity")
      end
    end

    context "when the service result is a ForbiddenFailure" do
      let(:error) { BaseService::ForbiddenFailure.new(result, code: "access_denied") }

      it "returns a forbidden error" do
        expect(subject).to be_a(GraphQL::ExecutionError)
        expect(subject.extensions).to include(status: 403, code: "access_denied")
      end
    end

    context "when the service result is a ThirdPartyFailure" do
      let(:error) do
        BaseService::ThirdPartyFailure.new(
          result,
          third_party: "3rd party service",
          error_code: "external_error",
          error_message: "External service failed"
        )
      end

      it "returns a third party failure error" do
        expect(subject).to be_a(GraphQL::ExecutionError)
        expect(subject.extensions).to include(status: 422, code: "third_party_error")
      end
    end

    context "when the service result is an unknown failure" do
      let(:error) { BaseService::UnknownTaxFailure.new(result, code: "unknown_tax", error_message: "error") }

      it "returns an execution error" do
        expect(subject).to be_a(GraphQL::ExecutionError)
        expect(subject.extensions).to include({status: 500, code: "unknown_tax"})
      end
    end
  end
end
