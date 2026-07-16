# frozen_string_literal: true

# Stubs Utils::SecurityLog for testing dependent services.
#
# @param available [Boolean] whether infrastructure is available (default: true)
#
# Usage:
#
#   include_context "with mocked security logger"
#   include_context "with mocked security logger", available: false
RSpec.shared_context "with mocked security logger" do |available: true|
  let!(:security_logger) do # rubocop:disable RSpec/LetSetup
    class_double(Utils::SecurityLog, produce: available, available?: available).as_stubbed_const
  end
end
