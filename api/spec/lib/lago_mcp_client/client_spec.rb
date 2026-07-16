# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::Client do
  subject(:client) { described_class.new(config) }

  let(:config) do
    instance_double(
      LagoMcpClient::Config,
      mcp_server_url: "https://mcp.example.com",
      timeout: 5,
      lago_api_key: "secret",
      lago_api_url: "https://api.lago.dev",
      headers: {"X-Custom" => "foo"}
    )
  end

  let(:http_client) { instance_double(LagoHttpClient::Client) }
  let(:sse_client) { instance_double(LagoMcpClient::SseClient, start: true, stop: true) }

  before do
    allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
    allow(LagoMcpClient::SseClient).to receive(:new).and_return(sse_client)
  end

  describe "#setup!" do
    let(:init_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 1\ndata: {\"result\": {\"protocolVersion\": \"2024-11-05\"}}",
        each_header: {"mcp-session-id" => "sess-abc"}
      )
    end

    let(:notif_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 2\ndata: {\"result\": {}}",
        each_header: {}
      )
    end

    before do
      allow(http_client).to receive(:post_with_response)
        .and_return(init_response, notif_response)
    end

    it "initializes connection and starts SSE client" do
      client.setup!

      expect(http_client).to have_received(:post_with_response).twice
      expect(LagoMcpClient::SseClient).to have_received(:new).with(
        url: "https://mcp.example.com",
        session_id: "sess-abc"
      )
      expect(sse_client).to have_received(:start)
    end

    it "sets the session_id from response headers" do
      client.setup!
      expect(client.session_id).to eq("sess-abc")
    end

    it "sets the sse_client" do
      client.setup!
      expect(client.sse_client).to eq(sse_client)
    end

    it "sends initialize request with correct parameters" do
      allow(http_client).to receive(:post_with_response)
        .and_return(init_response, notif_response)

      client.setup!

      expect(http_client).to have_received(:post_with_response).with(
        hash_including(
          method: "initialize",
          params: hash_including(
            protocolVersion: "2024-11-05",
            clientInfo: {name: "lago-mcp-client", version: "0.1"}
          )
        ),
        anything
      )
    end

    it "sends notifications/initialized after initialize" do
      allow(http_client).to receive(:post_with_response).and_return(init_response, notif_response)

      client.setup!

      expect(http_client).to have_received(:post_with_response).with(
        hash_including(method: "initialize"),
        anything
      ).ordered

      expect(http_client).to have_received(:post_with_response).with(
        hash_including(method: "notifications/initialized"),
        anything
      ).ordered
    end
  end

  describe "#list_tools" do
    let(:response_body) do
      {
        "result" => {
          "tools" => [
            {"name" => "tool_a", "description" => "desc a", "inputSchema" => {"type" => "object"}},
            {"name" => "tool_b", "description" => "desc b", "inputSchema" => {"type" => "object"}}
          ]
        }
      }
    end

    let(:mock_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 10\ndata: #{response_body.to_json}",
        each_header: {}
      )
    end

    before do
      allow(http_client).to receive(:post_with_response).and_return(mock_response)
      stub_const("LagoMcpClient::Tool", Struct.new(:name, :description, :input_schema, keyword_init: true))
    end

    it "returns an array of Tool instances" do
      tools = client.list_tools
      expect(tools.size).to eq(2)
      expect(tools.first.name).to eq("tool_a")
      expect(tools.last.description).to eq("desc b")
    end

    it "sends tools/list request" do
      client.list_tools

      expect(http_client).to have_received(:post_with_response).with(
        hash_including(method: "tools/list"),
        anything
      )
    end

    context "when no tools are returned" do
      let(:empty_response_body) { {"result" => {}} }
      let(:empty_mock_response) do
        instance_double(
          Net::HTTPResponse,
          code: "200",
          body: "id: 10\ndata: #{empty_response_body.to_json}",
          each_header: {}
        )
      end

      before do
        allow(http_client).to receive(:post_with_response).and_return(empty_mock_response)
      end

      it "returns an empty array" do
        expect(client.list_tools).to eq([])
      end
    end
  end

  describe "#call_tool" do
    let(:response_body) { {"result" => {"status" => "ok", "output" => "Hello World"}} }
    let(:mock_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 15\ndata: #{response_body.to_json}",
        each_header: {}
      )
    end

    before do
      allow(http_client).to receive(:post_with_response).and_return(mock_response)
    end

    it "calls the tool with given name and arguments" do
      result = client.call_tool("echo", {message: "hello"})
      expect(result).to eq({"status" => "ok", "output" => "Hello World"})
    end

    it "sends tools/call request with correct parameters" do
      client.call_tool("echo", {message: "hello"})

      expect(http_client).to have_received(:post_with_response).with(
        hash_including(
          method: "tools/call",
          params: {name: "echo", arguments: {message: "hello"}}
        ),
        anything
      )
    end

    context "when arguments are not provided" do
      it "defaults to empty hash" do
        client.call_tool("test_tool")

        expect(http_client).to have_received(:post_with_response).with(
          hash_including(
            params: {name: "test_tool", arguments: {}}
          ),
          anything
        )
      end
    end
  end

  describe "#close_session" do
    let(:mock_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 20\ndata: {\"result\": {}}",
        each_header: {}
      )
    end

    before do
      client.instance_variable_set(:@sse_client, sse_client)
      allow(http_client).to receive(:post_with_response).and_return(mock_response)
    end

    it "stops the SSE client" do
      client.close_session
      expect(sse_client).to have_received(:stop)
    end

    it "sends close request" do
      client.close_session
      expect(http_client).to have_received(:post_with_response).with(
        hash_including(method: "close"),
        anything
      )
    end

    context "when sse_client is nil" do
      before do
        client.instance_variable_set(:@sse_client, nil)
      end

      it "does not raise error" do
        expect { client.close_session }.not_to raise_error
      end
    end
  end

  describe "error handling" do
    context "when HTTP request fails" do
      let(:error_message) { "Connection refused" }

      before do
        allow(http_client).to receive(:post_with_response).and_raise(StandardError.new(error_message))
      end

      it "returns error hash for list_tools" do
        result = client.list_tools
        expect(result).to eq([])
      end

      it "returns error hash for call_tool" do
        result = client.call_tool("test", {})
        expect(result).to be_nil
      end
    end

    context "when response body has invalid JSON" do
      let(:invalid_response) do
        instance_double(
          Net::HTTPResponse,
          code: "200",
          body: "data: {invalid json}",
          each_header: {}
        )
      end

      before do
        allow(http_client).to receive(:post_with_response).and_return(invalid_response)
      end

      it "handles parsing error gracefully" do
        result = client.list_tools
        expect(result).to eq([])
      end
    end

    context "when response has no data line" do
      let(:no_data_response) do
        instance_double(
          Net::HTTPResponse,
          code: "200",
          body: "id: 123\n",
          each_header: {}
        )
      end

      before do
        allow(http_client).to receive(:post_with_response).and_return(no_data_response)
      end

      it "handles missing data gracefully" do
        result = client.list_tools
        expect(result).to eq([])
      end
    end
  end

  describe "headers management" do
    let(:init_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 1\ndata: {\"result\": {}}",
        each_header: {"mcp-session-id" => "sess-123"}
      )
    end

    let(:notif_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 2\ndata: {\"result\": {}}",
        each_header: {}
      )
    end

    let(:tools_response) do
      instance_double(
        Net::HTTPResponse,
        code: "200",
        body: "id: 3\ndata: {\"result\": {\"tools\": []}}",
        each_header: {}
      )
    end

    before do
      allow(http_client).to receive(:post_with_response)
        .and_return(init_response, notif_response, tools_response)
    end

    it "includes all required headers in requests" do
      client.setup!
      client.list_tools

      expect(http_client).to have_received(:post_with_response).with(
        anything,
        hash_including(
          "Content-Type" => "application/json",
          "Accept" => "application/json,text/event-stream",
          "Mcp-Session-Id" => "sess-123",
          "X-LAGO-API-KEY" => "secret",
          "X-LAGO-API-URL" => "https://api.lago.dev",
          "X-Custom" => "foo"
        )
      ).at_least(:once)
    end

    it "includes custom headers from config" do
      client.setup!
      client.list_tools

      expect(http_client).to have_received(:post_with_response).with(
        anything,
        hash_including("X-Custom" => "foo")
      ).at_least(:once)
    end
  end
end
