# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::Metadata do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiMetadata")
    expect(subject).to have_field(:current_page).of_type("Int!")
    expect(subject).to have_field(:next_page).of_type("Int!")
    expect(subject).to have_field(:prev_page).of_type("Int!")
    expect(subject).to have_field(:total_count).of_type("Int!")
    expect(subject).to have_field(:total_pages).of_type("Int!")
  end
end
