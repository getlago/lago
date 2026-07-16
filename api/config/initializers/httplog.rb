# frozen_string_literal: true

return unless defined? HttpLog

HttpLog.configure do |config|
  config.enabled = true
  config.color = :yellow

  config.url_denylist_pattern = /clickhouse:8123/
end
