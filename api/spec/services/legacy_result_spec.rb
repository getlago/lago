# frozen_string_literal: true

require "rails_helper"

RSpec.describe BaseService::LegacyResult do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:result) { described_class.new }

  it_behaves_like "a result object"

  it { expect(subject).to be_a(OpenStruct) }
end
