# frozen_string_literal: true

require "rails_helper"
require "datadog/auto_instrument"

RSpec.describe Middlewares::DatadogMiddleware do
  let(:service_class) do
    Class.new(BaseService) do
      use Middlewares::DatadogMiddleware

      def self.name
        "CustomeService"
      end

      def call
        result
      end
    end
  end

  let(:span) { instance_double(Datadog::Tracing::SpanOperation) }

  before do
    allow(Datadog::Tracing).to receive(:trace)
      .with("service.call", service: "lago-api", resource: "CustomeService")
      .and_return(span)
  end

  describe "Tracking" do
    it "tracks the service call" do
      allow(span).to receive(:set_tag).with("result.status", "success")
      allow(span).to receive(:finish)

      service_class.call

      expect(Datadog::Tracing).to have_received(:trace).with("service.call", service: "lago-api", resource: "CustomeService")
      expect(span).to have_received(:set_tag).with("result.status", "success")
      expect(span).to have_received(:finish)
    end

    context "when result is a failure" do
      let(:service_class) do
        Class.new(BaseService) do
          use Middlewares::DatadogMiddleware

          def self.name
            "CustomeService"
          end

          def call
            result.not_found_failure!(resource: "fake")
          end
        end
      end

      it "tracks the service call" do
        allow(span).to receive(:set_tag).with("result.status", "failure")
        allow(span).to receive(:record_exception).with(BaseService::NotFoundFailure)
        allow(span).to receive(:finish)

        service_class.call

        expect(Datadog::Tracing).to have_received(:trace).with("service.call", service: "lago-api", resource: "CustomeService")
        expect(span).to have_received(:set_tag).with("result.status", "failure")
        expect(span).to have_received(:record_exception).with(BaseService::NotFoundFailure)
        expect(span).to have_received(:finish)
      end
    end

    context "when service raises an error" do
      let(:service_class) do
        Class.new(BaseService) do
          use Middlewares::DatadogMiddleware

          def self.name
            "CustomeService"
          end

          def call
            raise StandardError, "Service error"
          end
        end
      end

      it "tracks the service call" do
        allow(span).to receive(:set_tag).with("result.status", "failure")
        allow(span).to receive(:record_exception).with(StandardError)
        allow(span).to receive(:finish)

        expect { service_class.call }.to raise_error(StandardError)

        expect(Datadog::Tracing).to have_received(:trace).with("service.call", service: "lago-api", resource: "CustomeService")
        expect(span).to have_received(:set_tag).with("result.status", "failure")
        expect(span).to have_received(:record_exception).with(StandardError)
        expect(span).to have_received(:finish)
      end
    end
  end
end
