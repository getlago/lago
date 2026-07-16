# frozen_string_literal: true

shared_examples "an invalid filter" do |filter, value, error_message|
  let(:filters) { {filter => value} }

  it "is invalid when #{filter} is set to #{value.inspect}" do
    expect(result.success?).to be(false)
    expect(result.errors.to_h).to include({filter => error_message})
  end
end
