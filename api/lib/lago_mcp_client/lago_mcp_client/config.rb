# frozen_string_literal: true

module LagoMcpClient
  class Config
    attr_accessor :mcp_server_url, :lago_api_key, :timeout, :headers

    def initialize(mcp_server_url:, lago_api_key:, timeout: 30, headers: {})
      @mcp_server_url = mcp_server_url
      @lago_api_key = lago_api_key
      @timeout = timeout
      @headers = headers
    end

    def lago_api_url
      @lago_api_url ||= URI.join(ENV["LAGO_API_URL"], "/api/v1").to_s
    end
  end
end
