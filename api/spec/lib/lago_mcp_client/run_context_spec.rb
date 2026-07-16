# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::RunContext do
  subject(:run_context) { described_class.new(client:) }

  let(:client) { instance_double("LagoMcpClient::Client") }
  let(:tool_sum) { instance_double("LagoMcpClient::Tool", name: "sum", description: "Adds numbers", input_schema: {"a" => "int", "b" => "int"}) }
  let(:tool_echo) { instance_double("LagoMcpClient::Tool", name: "echo", description: "Echoes text", input_schema: {"msg" => "string"}) }

  describe "#setup!" do
    it "loads tools from the client and returns self" do
      allow(client).to receive(:list_tools).and_return([tool_sum, tool_echo])

      result = run_context.setup!

      expect(result).to eq(run_context)
      expect(run_context.to_model_tools.map { |t| t[:function][:name] }).to contain_exactly("sum", "echo")
    end
  end

  describe "#to_model_tools" do
    before do
      allow(client).to receive(:list_tools).and_return([tool_sum])
      run_context.setup!
    end

    it "returns formatted model tool definitions" do
      expect(run_context.to_model_tools).to eq([
        {
          type: "function",
          function: {
            name: "sum",
            description: "Adds numbers",
            parameters: {"a" => "int", "b" => "int"}
          }
        }
      ])
    end
  end

  describe "#process_tool_calls" do
    before do
      allow(client).to receive(:list_tools).and_return([tool_sum])
      run_context.setup!
      allow(client).to receive(:call_tool).with("sum", {"a" => 1, "b" => 2}).and_return({"result" => 3})
    end

    let(:tool_call) do
      {
        "id" => "123",
        "function" => {
          "name" => "sum",
          "arguments" => '{"a":1,"b":2}'
        }
      }
    end

    it "executes a valid tool call and returns JSON-formatted results" do
      result = run_context.process_tool_calls([tool_call])

      expect(result).to eq([
        {
          tool_call_id: "123",
          role: "tool",
          content: JSON.generate({"result" => 3})
        }
      ])
    end

    it "raises an error if the tool does not exist" do
      fake_call = {
        "id" => "456",
        "function" => {"name" => "missing", "arguments" => "{}"}
      }

      expect { run_context.process_tool_calls([fake_call]) }.to raise_error("Tool 'missing' not found")
    end
  end
end
