# frozen_string_literal: true

module LagoMcpClient
  module SseParser
    def parse_sse_data(line)
      return if line.nil? || line.strip.empty?
      return unless line.start_with?("data: ")

      JSON.parse(line.delete_prefix("data: ").strip)
    rescue JSON::ParserError => e
      Rails.logger.warn("SSE parse error: #{e.message} for line: #{line.truncate(100)}")
      nil
    end

    def extract_sse_id(line)
      return unless line&.start_with?("id: ")

      line.delete_prefix("id: ").strip
    end

    def find_sse_data_line(body)
      return unless body

      body.each_line.find { |line| line.start_with?("data: ") }
    end

    def find_sse_id_line(body)
      return unless body

      body.each_line.find { |line| line.start_with?("id: ") }
    end
  end
end
