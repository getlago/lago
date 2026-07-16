# frozen_string_literal: true

module LagoMcpClient
  class SseClient
    include SseParser

    def initialize(url:, session_id:)
      @uri = URI(url)
      @session_id = session_id
      @running = false
      @mutex = Mutex.new
      @thread = nil
      @callbacks = []
    end

    def start(&block)
      @mutex.synchronize { @callbacks << block if block }
      @running = true
      @thread ||= Thread.new { run } # rubocop:disable ThreadSafety/NewThread
    end

    def stop
      @running = false
      @thread&.join(1)
      @thread = nil
    end

    private

    def run
      Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(@uri)
        request["Mcp-Session-Id"] = @session_id
        request["Accept"] = "application/json,text/event-stream"
        request["Cache-Control"] = "no-cache"

        http.request(request) do |response|
          next unless response.code == "200"

          response.read_body do |chunk|
            break unless @running

            chunk.each_line do |line|
              event_data = parse_sse_data(line)
              @callbacks.each { |cb| cb&.call(event_data) } if event_data
            end
          end
        end
      end
    rescue => e
      Rails.logger.error("SSE client error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end
