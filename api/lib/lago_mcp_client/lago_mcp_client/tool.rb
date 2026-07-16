# frozen_string_literal: true

module LagoMcpClient
  class Tool
    attr_reader :name, :description, :input_schema

    def initialize(name:, description:, input_schema:)
      @name = name
      @description = description
      @input_schema = input_schema
    end

    def to_h
      {
        name:,
        description:,
        input_schema:
      }
    end
  end
end
