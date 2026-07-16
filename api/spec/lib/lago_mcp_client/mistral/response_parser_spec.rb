# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::Mistral::ResponseParser do
  subject(:parser) { described_class.new }

  describe "#process" do
    context "when receiving [DONE] marker" do
      it "does nothing" do
        parser.process("[DONE]")

        expect(parser.conversation_id).to be_nil
        expect(parser.outputs).to be_empty
        expect(parser.tool_calls).to be_empty
      end
    end

    context "when receiving conversation_id" do
      it "extracts conversation_id from response" do
        parser.process({conversation_id: "conv_123", type: "conversation.response.done"}.to_json)

        expect(parser.conversation_id).to eq("conv_123")
      end
    end

    context "when receiving message.output.delta" do
      it "yields content to the block" do
        chunks = []

        parser.process({type: "message.output.delta", content: "Hello"}.to_json) { |c| chunks << c }
        parser.process({type: "message.output.delta", content: " world"}.to_json) { |c| chunks << c }

        expect(chunks).to eq(["Hello", " world"])
      end

      it "does not yield when content is blank" do
        chunks = []

        parser.process({type: "message.output.delta", content: ""}.to_json) { |c| chunks << c }
        parser.process({type: "message.output.delta", content: nil}.to_json) { |c| chunks << c }

        expect(chunks).to be_empty
      end

      it "does not yield when no block given" do
        expect { parser.process({type: "message.output.delta", content: "Hello"}.to_json) }.not_to raise_error
      end
    end

    context "when receiving function.call" do
      it "adds tool call to the list" do
        parser.process({
          type: "function.call",
          tool_call_id: "call_123",
          name: "get_customer",
          arguments: '{"id": "456"}'
        }.to_json)

        expect(parser.tool_calls).to eq([
          {
            "id" => "call_123",
            "type" => "function",
            "function" => {
              "name" => "get_customer",
              "arguments" => '{"id": "456"}'
            }
          }
        ])
      end

      it "handles missing arguments" do
        parser.process({
          type: "function.call",
          tool_call_id: "call_123",
          name: "list_all"
        }.to_json)

        expect(parser.tool_calls.first.dig("function", "arguments")).to eq("")
      end
    end

    context "when receiving function.call.delta (streaming)" do
      it "accumulates arguments across multiple deltas" do
        parser.process({
          type: "function.call.delta",
          tool_call_id: "call_stream",
          name: "search",
          arguments: '{"query":'
        }.to_json)

        parser.process({
          type: "function.call.delta",
          tool_call_id: "call_stream",
          arguments: ' "test"}'
        }.to_json)

        expect(parser.tool_calls).to eq([
          {
            "id" => "call_stream",
            "type" => "function",
            "function" => {
              "name" => "search",
              "arguments" => '{"query": "test"}'
            }
          }
        ])
      end
    end

    context "when receiving outputs array with message.output" do
      it "adds outputs to the list" do
        parser.process({
          outputs: [{type: "message.output", content: "Final response"}]
        }.to_json)

        expect(parser.outputs).to eq([{"type" => "message.output", "content" => "Final response"}])
      end
    end

    context "when receiving outputs array with tool.call" do
      it "adds tool calls from outputs" do
        parser.process({
          outputs: [
            {
              type: "tool.call",
              tool_call_id: "tool_789",
              name: "list_customers",
              arguments: "{}"
            }
          ]
        }.to_json)

        expect(parser.tool_calls).to eq([
          {
            "id" => "tool_789",
            "type" => "function",
            "function" => {
              "name" => "list_customers",
              "arguments" => "{}"
            }
          }
        ])
      end

      it "extracts tool call from nested function structure" do
        parser.process({
          outputs: [
            {
              type: "function.call",
              id: "func_123",
              function: {name: "get_data", arguments: '{"key": "value"}'}
            }
          ]
        }.to_json)

        expect(parser.tool_calls.first).to include(
          "id" => "func_123",
          "function" => {"name" => "get_data", "arguments" => '{"key": "value"}'}
        )
      end
    end

    context "when JSON parsing fails" do
      it "logs error and continues" do
        allow(Rails.logger).to receive(:error)

        parser.process("invalid json {")

        expect(Rails.logger).to have_received(:error).with(/Failed to parse SSE data/)
        expect(Rails.logger).to have_received(:error).with(/Parse error/)
      end
    end
  end

  describe "#to_result" do
    it "returns hash with conversation_id, outputs, and tool_calls" do
      parser.process({conversation_id: "conv_abc"}.to_json)
      parser.process({outputs: [{type: "message.output", content: "Hi"}]}.to_json)
      parser.process({type: "function.call", tool_call_id: "call_1", name: "test", arguments: "{}"}.to_json)

      result = parser.to_result

      expect(result).to eq({
        "conversation_id" => "conv_abc",
        "outputs" => [{"type" => "message.output", "content" => "Hi"}],
        "tool_calls" => [{"id" => "call_1", "type" => "function", "function" => {"name" => "test", "arguments" => "{}"}}]
      })
    end

    it "returns nil for tool_calls when empty" do
      parser.process({conversation_id: "conv_abc"}.to_json)

      expect(parser.to_result["tool_calls"]).to be_nil
    end
  end
end
