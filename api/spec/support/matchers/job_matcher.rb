# frozen_string_literal: true

# This matcher ensure that a job is enqueued only after a transaction is committed to ensure no race-condition may
# happen.
RSpec::Matchers.define :have_enqueued_job_after_commit do |job|
  supports_block_expectations
  match(notify_expectation_failures: true) do |block|
    ApplicationRecord.transaction do
      block.call

      expect(job).not_to have_been_enqueued, "Expected #{job} to not have been enqueued before commit, but it was."
    end

    args = @args || []
    kwargs = @kwargs || {}

    expect(job).to have_been_enqueued.with(*args, **kwargs, &@block).send(expectation_type, expected_number)
  end

  match_when_negated do |block|
    raise "The `have_enqueued_job_after_commit` matcher does not support negation. Use `expect { ... }.not_to have_enqueued_job` instead."
  end

  chain :with do |*args, **kwargs, &block|
    @args = args
    @kwargs = kwargs
    @block = block
  end

  chain :twice do
    set_expected_number(:exactly, 2)
  end

  chain :thrice do
    set_expected_number(:exactly, 3)
  end

  chain :exactly do |count|
    set_expected_number(:exactly, count)
  end

  chain :at_least do |count|
    set_expected_number(:at_least, count)
  end

  chain :at_most do |count|
    set_expected_number(:at_most, count)
  end

  chain :times do
  end

  private

  def set_expected_number(relativity, count)
    @expectation_type = relativity
    @expected_number = case count
    when :once then 1
    when :twice then 2
    when :thrice then 3
    else Integer(count)
    end
  end

  def expected_number
    @expected_number || 1
  end

  def expectation_type
    @expectation_type || :exactly
  end
end

RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job
