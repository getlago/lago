# frozen_string_literal: true

module LagoMcpClient
  class ToolNotFoundError < StandardError
    attr_reader :tool_name

    def initialize(tool_name)
      @tool_name = tool_name
      super("Tool '#{tool_name}' not found")
    end
  end

  class RunContext
    attr_reader :client

    def initialize(client:)
      @client = client
      @tools = []
      @tools_results = []
      @mutex = Mutex.new
    end

    def setup!
      @tools = client.list_tools
      self
    end

    def to_model_tools
      @tools.map do |tool|
        {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description,
            parameters: tool.input_schema
          }
        }
      end
    end

    def process_tool_calls(tool_calls)
      results = []

      tool_calls.each do |tool_call|
        function_name = tool_call.dig("function", "name")
        arguments = JSON.parse(tool_call.dig("function", "arguments") || "{}")

        result = call_tool(function_name, arguments)
        results << {
          tool_call_id: tool_call["id"],
          role: "tool",
          content: JSON.generate(result)
        }
      end

      results
    end

    private

    def get_tool(name)
      @tools.find { |tool| tool.name == name }
    end

    def call_tool(name, arguments = {})
      tool = get_tool(name)
      raise ToolNotFoundError.new(name) unless tool

      result = client.call_tool(name, arguments)
      @tools_results << {name => result}
      result
    end
  end
end
