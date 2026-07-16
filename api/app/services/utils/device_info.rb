# frozen_string_literal: true

module Utils
  # Parses device metadata from an HTTP request User-Agent header.
  class DeviceInfo
    def self.parse(request)
      user_agent = request&.user_agent
      return if user_agent.blank?

      client = DeviceDetector.new(user_agent)
      {
        user_agent:,
        ip_address: request.remote_ip,
        browser: "#{client.name} #{client.full_version}".strip,
        os: client.os_name,
        device_type: client.device_type || "desktop"
      }
    end
  end
end
