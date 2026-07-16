# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::SseClient do
  subject(:sse_client) { described_class.new(url: url, session_id: session_id) }

  let(:url) { "https://mcp.example.com/sse" }
  let(:session_id) { "sess-abc123" }

  let(:http) { instance_double(Net::HTTP) }
  let(:response) { instance_double(Net::HTTPResponse, code: "200") }
  let(:request) { instance_double(Net::HTTP::Get) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(Net::HTTP::Get).to receive(:new).and_return(request)
    allow(request).to receive(:[]=)
    allow(http).to receive(:request).with(request).and_yield(response)
    allow(response).to receive(:read_body)
  end

  describe "#start" do
    before do
      allow(Thread).to receive(:new).and_return(instance_double(Thread))
    end

    it "starts a background thread" do
      sse_client.start
      expect(Thread).to have_received(:new)
    end

    it "registers the callback" do
      callback_called = false
      sse_client.start { callback_called = true }

      callbacks = sse_client.instance_variable_get(:@callbacks)
      expect(callbacks.size).to eq(1)
    end

    it "sets running to true" do
      sse_client.start
      expect(sse_client.instance_variable_get(:@running)).to be(true)
    end

    it "does not start multiple threads when called multiple times" do
      sse_client.start
      sse_client.start

      expect(Thread).to have_received(:new).once
    end
  end

  describe "#stop" do
    let(:mock_thread) { instance_double(Thread, join: true) }

    before do
      allow(Thread).to receive(:new).and_return(mock_thread)
      sse_client.start
    end

    it "sets running to false" do
      sse_client.stop
      expect(sse_client.instance_variable_get(:@running)).to be(false)
    end

    it "joins the thread with timeout" do
      sse_client.stop
      expect(mock_thread).to have_received(:join).with(1)
    end

    it "clears the thread reference" do
      sse_client.stop
      expect(sse_client.instance_variable_get(:@thread)).to be_nil
    end
  end

  describe "HTTP request configuration" do
    before do
      allow(Thread).to receive(:new) do |&block|
        block.call
        instance_double(Thread)
      end
    end

    it "sets the correct headers" do
      sse_client.start

      expect(request).to have_received(:[]=).with("Mcp-Session-Id", session_id)
      expect(request).to have_received(:[]=).with("Accept", "application/json,text/event-stream")
      expect(request).to have_received(:[]=).with("Cache-Control", "no-cache")
    end

    it "uses SSL for https URLs" do
      sse_client.start

      expect(Net::HTTP).to have_received(:start).with("mcp.example.com", 443, use_ssl: true)
    end

    context "with http URL" do
      let(:url) { "http://mcp.example.com/sse" }

      it "does not use SSL" do
        sse_client.start

        expect(Net::HTTP).to have_received(:start).with("mcp.example.com", 80, use_ssl: false)
      end
    end
  end

  describe "callback invocation" do
    before do
      allow(Thread).to receive(:new) do |&block|
        block.call
        instance_double(Thread)
      end
    end

    it "invokes callbacks with parsed event data" do
      received_data = []
      allow(response).to receive(:read_body).and_yield("data: {\"message\": \"hello\"}\n")

      sse_client.start { |data| received_data << data }

      expect(received_data).to eq([{"message" => "hello"}])
    end

    it "invokes multiple callbacks" do
      results1 = []
      results2 = []
      allow(response).to receive(:read_body).and_yield("data: {\"test\": true}\n")

      # Pre-register both callbacks before starting
      sse_client.instance_variable_get(:@callbacks) << proc { |data| results1 << data }
      sse_client.instance_variable_get(:@callbacks) << proc { |data| results2 << data }

      sse_client.start

      expect(results1).to eq([{"test" => true}])
      expect(results2).to eq([{"test" => true}])
    end

    it "handles multiple events in a single chunk" do
      received_data = []
      allow(response).to receive(:read_body).and_yield("data: {\"event\": 1}\ndata: {\"event\": 2}\n")

      sse_client.start { |data| received_data << data }

      expect(received_data).to eq([{"event" => 1}, {"event" => 2}])
    end
  end

  describe "error handling" do
    before do
      allow(Rails.logger).to receive(:error)
      allow(Thread).to receive(:new) do |&block|
        block.call
        instance_double(Thread)
      end
    end

    it "logs errors when HTTP request fails" do
      allow(Net::HTTP).to receive(:start).and_raise(StandardError.new("Connection failed"))

      sse_client.start

      expect(Rails.logger).to have_received(:error).with("SSE client error: Connection failed")
      expect(Rails.logger).to have_received(:error).twice
    end

    context "with non-200 response" do
      let(:response) { instance_double(Net::HTTPResponse, code: "500") }

      it "does not process the response body" do
        sse_client.start
        expect(response).not_to have_received(:read_body)
      end
    end
  end
end
