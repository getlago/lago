# frozen_string_literal: true

RSpec::Matchers.define :match_datetime do |expectation|
  match do |subject|
    subject = Time.zone.parse(subject).change(usec: 0) if subject.is_a?(String)
    expectation = Time.zone.parse(expectation) if expectation.is_a?(String)

    subject.change(usec: 0) == expectation.change(usec: 0)
  end
end
