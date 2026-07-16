# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::EmailActivityLog, :capture_kafka_messages do
  let(:invoice) { create(:invoice) }
  let(:organization) { invoice.organization }
  let(:customer) { invoice.customer }

  let(:message) do
    instance_double(
      Mail::Message,
      subject: "Test Subject",
      to: ["to@example.com"],
      cc: nil,
      bcc: nil,
      text_part: nil,
      html_part: instance_double(Mail::Part, body: instance_double(Mail::Body, decoded: "<h1>Hello</h1><p>Body preview</p>")),
      body: instance_double(Mail::Body, decoded: "")
    )
  end

  before do
    stub_const("#{described_class}::AVAILABLE", true)
    stub_const("#{described_class}::TOPIC", "activity_logs")

    travel_to(Time.zone.parse("2024-01-15 12:00:00"))
    allow(SecureRandom).to receive(:uuid).and_return("test-activity-id")
  end

  describe ".produce" do
    it "sends to kafka with correct topic and key" do
      described_class.produce(document: invoice, message:)

      expect(kafka_messages.size).to eq(1)
      expect(kafka_messages.first[:topic]).to eq("activity_logs")
      expect(kafka_messages.first[:key]).to eq("#{organization.id}--test-activity-id")
    end

    it "sets status to sent by default" do
      described_class.produce(document: invoice, message:)

      payload = JSON.parse(kafka_messages.first[:payload])
      activity_object = payload["activity_object"]

      expect(payload["activity_source"]).to eq("system")
      expect(payload["activity_type"]).to eq("email.sent")
      expect(activity_object["status"]).to eq("sent")
    end

    it "sets status to resent when resend is true" do
      described_class.produce(document: invoice, message:, resend: true)

      payload = JSON.parse(kafka_messages.first[:payload])
      activity_object = payload["activity_object"]

      expect(activity_object["status"]).to eq("resent")
    end

    it "sets status to failed when error provided" do
      described_class.produce(document: invoice, message:, error: StandardError.new("SMTP failed"))

      payload = JSON.parse(kafka_messages.first[:payload])
      activity_object = payload["activity_object"]

      expect(activity_object["status"]).to eq("failed")
      expect(JSON.parse(activity_object["error"])).to eq("class" => "StandardError", "message" => "SMTP failed")
    end

    it "sets activity_source to api when api_key_id provided" do
      described_class.produce(document: invoice, message:, api_key_id: "key-123")

      payload = JSON.parse(kafka_messages.first[:payload])
      expect(payload["activity_source"]).to eq("api")
      expect(payload["api_key_id"]).to eq("key-123")
    end

    it "sets activity_source to front when user_id provided" do
      described_class.produce(document: invoice, message:, user_id: "user-456")

      payload = JSON.parse(kafka_messages.first[:payload])
      expect(payload["activity_source"]).to eq("front")
      expect(payload["user_id"]).to eq("user-456")
    end

    it "does not send to kafka when not available" do
      stub_const("#{described_class}::AVAILABLE", false)

      described_class.produce(document: invoice, message:)

      expect(kafka_messages).to be_empty
    end

    it "does not send to kafka when document is nil" do
      described_class.produce(document: nil, message:)

      expect(kafka_messages).to be_empty
    end

    it "does not send to kafka when message is nil" do
      described_class.produce(document: invoice, message: nil)

      expect(kafka_messages).to be_empty
    end

    [
      {exception: WaterDrop::Errors::ProduceError, message: "#<Rdkafka::RdkafkaError: Local: Unknown topic (unknown_topic)>"},
      {exception: WaterDrop::Errors::MessageInvalidError, message: "Message is too large"}
    ].each do |error_context|
      exception = error_context[:exception]
      exception_message = error_context[:message]
      context "when producer raises #{exception}" do
        subject(:produce) { described_class.produce(document: invoice, message:) }

        let(:result) { BaseService::Result.new }

        before do
          allow(karafka_producer).to receive(:produce_async).and_raise(exception.new(exception_message))
        end

        context "when sentry is configured", :sentry do
          it "captures the exception and returns false" do
            expect(produce).to eq false
            expect(sentry_events).to include_sentry_event(exception: exception, message: exception_message)
          end
        end

        context "when sentry is not configured" do
          it "re-raises the error" do
            expect { produce }.to raise_error(exception, exception_message)
            expect(sentry_events).to be_empty
          end
        end
      end
    end

    context "with credit_note document" do
      let(:credit_note) { create(:credit_note, invoice:, customer:) }

      it "includes credit_note number in document reference" do
        described_class.produce(document: credit_note, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        activity_object = payload["activity_object"]
        document = JSON.parse(activity_object["document"])

        expect(document["type"]).to eq("CreditNote")
        expect(document["number"]).to eq(credit_note.number)
      end
    end

    context "with html-only email" do
      it "extracts body preview from html_part with tags stripped" do
        described_class.produce(document: invoice, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        email = JSON.parse(payload["activity_object"]["email"])

        expect(email["body_preview"]).to eq("Hello Body preview")
      end
    end

    context "with text_part present" do
      let(:message) do
        instance_double(
          Mail::Message,
          subject: "Test Subject",
          to: ["to@example.com"],
          cc: nil,
          bcc: nil,
          text_part: instance_double(Mail::Part, body: instance_double(Mail::Body, decoded: "Plain text body")),
          html_part: instance_double(Mail::Part, body: instance_double(Mail::Body, decoded: "<p>HTML body</p>")),
          body: instance_double(Mail::Body, decoded: "")
        )
      end

      it "prefers text_part over html_part" do
        described_class.produce(document: invoice, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        email = JSON.parse(payload["activity_object"]["email"])

        expect(email["body_preview"]).to eq("Plain text body")
      end
    end

    context "with simple non-multipart message" do
      let(:message) do
        instance_double(
          Mail::Message,
          subject: "Test Subject",
          to: ["to@example.com"],
          cc: nil,
          bcc: nil,
          text_part: nil,
          html_part: nil,
          body: instance_double(Mail::Body, decoded: "Simple body text")
        )
      end

      it "falls back to message body" do
        described_class.produce(document: invoice, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        email = JSON.parse(payload["activity_object"]["email"])

        expect(email["body_preview"]).to eq("Simple body text")
      end
    end

    context "with empty body" do
      let(:message) do
        instance_double(
          Mail::Message,
          subject: "Test Subject",
          to: ["to@example.com"],
          cc: nil,
          bcc: nil,
          text_part: nil,
          html_part: nil,
          body: instance_double(Mail::Body, decoded: "")
        )
      end

      it "returns empty string" do
        described_class.produce(document: invoice, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        email = JSON.parse(payload["activity_object"]["email"])

        expect(email["body_preview"]).to eq("")
      end
    end

    context "with long html body" do
      let(:long_html) { "<p>#{"a" * 600}</p>" }

      let(:message) do
        instance_double(
          Mail::Message,
          subject: "Test Subject",
          to: ["to@example.com"],
          cc: nil,
          bcc: nil,
          text_part: nil,
          html_part: instance_double(Mail::Part, body: instance_double(Mail::Body, decoded: long_html)),
          body: instance_double(Mail::Body, decoded: "")
        )
      end

      it "truncates to BODY_PREVIEW_LENGTH" do
        described_class.produce(document: invoice, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        email = JSON.parse(payload["activity_object"]["email"])

        expect(email["body_preview"].length).to be <= described_class::BODY_PREVIEW_LENGTH
      end
    end

    context "with payment_receipt document" do
      let(:payment_receipt) do
        payment = create(
          :payment,
          payable: invoice,
          customer:,
          payment_provider: nil,
          payment_provider_customer: nil,
          payment_type: "manual",
          reference: "manual-payment-ref",
          amount_cents: invoice.total_amount_cents
        )
        create(:payment_receipt, payment:, organization:)
      end

      it "includes payment_receipt number in document reference" do
        described_class.produce(document: payment_receipt, message:)

        payload = JSON.parse(kafka_messages.first[:payload])
        activity_object = payload["activity_object"]
        document = JSON.parse(activity_object["document"])

        expect(document["type"]).to eq("PaymentReceipt")
        expect(document["number"]).to eq(payment_receipt.number)
      end

      it "uses payment_receipt as resource" do
        described_class.produce(document: payment_receipt, message:)

        payload = JSON.parse(kafka_messages.first[:payload])

        expect(payload["resource_type"]).to eq("PaymentReceipt")
        expect(payload["resource_id"]).to eq(payment_receipt.id)
      end
    end
  end
end
