# frozen_string_literal: true

require "cop_helper"

RSpec.describe Cops::ActiveJobPerformAllLaterCop, :config do
  it "registers an offense when using ActiveJob.perform_all_later" do
    expect_offense(<<~RUBY)
      ActiveJob.perform_all_later(jobs)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using `ActiveJob.perform_all_later`. Use `ApplicationJob.perform_all_later` instead.
    RUBY
  end

  it "does not register an offense when using ApplicationJob.perform_all_later" do
    expect_no_offenses(<<~RUBY)
      ApplicationJob.perform_all_later(jobs)
    RUBY
  end
end
