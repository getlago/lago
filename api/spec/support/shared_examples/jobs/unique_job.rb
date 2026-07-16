# frozen_string_literal: true

RSpec.shared_examples "a unique job" do
  around do |example|
    ActiveJob::Uniqueness.reset_manager!
    example.run
    ActiveJob::Uniqueness.test_mode!
  end

  it "does not enqueue duplicate jobs" do
    expect do
      described_class.perform_later(*job_args)
      described_class.perform_later(*job_args)
    end.to change { enqueued_jobs.count }.by(1) # rubocop:disable RSpec/ExpectChange
  end
end
