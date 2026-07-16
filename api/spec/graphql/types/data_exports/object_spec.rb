# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataExports::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:status).of_type("DataExportStatusEnum!")
  end
end
