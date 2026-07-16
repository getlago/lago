# frozen_string_literal: true

RSpec::Matchers.define :have_produced do |activity_type|
  match do |actual|
    @actual = actual
    @activity_type = activity_type

    expected_params = [@object, activity_type]
    expected_params << {after_commit: @after_commit} unless @after_commit.nil?

    expect(actual).to have_received(:produce).with(*expected_params)
  end

  chain :with do |object|
    @object = object
  end

  chain :after_commit do
    @after_commit = true
  end

  chain :not_after_commit do
    @after_commit = false
  end

  failure_message do
    base_message = "expected #{@actual} to have produced '#{@activity_type}'"
    base_message += " with #{@object.inspect} and {after_commit: #{@after_commit}}"
    base_message
  end

  failure_message_when_negated do
    base_message = "expected #{@actual} not to have produced '#{@activity_type}'"
    base_message += " with #{@object.inspect} and {after_commit: #{@after_commit}}"
    base_message
  end

  description do
    "produce '#{@activity_type}'"
  end
end
