# frozen_string_literal: true

require "benchmark"
require "ostruct"

request = OpenStruct.new(
  user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
  remote_ip: "192.168.1.1"
)

n = 10_000

Benchmark.bm(20) do |x|
  x.report("DeviceInfo.parse (#{n} times)") { n.times { Utils::DeviceInfo.parse(request) } }
end
