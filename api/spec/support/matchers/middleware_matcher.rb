# frozen_string_literal: true

RSpec::Matchers.define :use_middleware do |middleware|
  match do |service_class|
    service_klass = service_class || described_class
    expect(service_klass.middlewares.map(&:first)).to include(middleware)
  end
end
