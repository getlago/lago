# frozen_string_literal: true

PassedTime = Struct.new(:days)

RSpec.shared_context "with Time travel enabled" do
  # Standard time on which all things start
  # can simply be overriden via a let(:time0) {} in your own spec!
  let(:time0) { DateTime.new(2022, 12, 1) }
  let(:passed_time) { PassedTime.new(0) }

  before do
    passed_time.days = 0
    travel_to time0
  end

  def pass_time(amount)
    amount_of_days = amount / 1.day
    amount_of_days.times do |i|
      perform_billing
      travel_to time0 + passed_time.days + i.day
    end
    perform_billing
    passed_time.days += amount_of_days
  end
end
