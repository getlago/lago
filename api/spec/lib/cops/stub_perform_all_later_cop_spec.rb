# frozen_string_literal: true

require "cop_helper"

RSpec.describe Cops::StubPerformAllLaterCop, :config do
  it "registers an offense when stubbing perform_all_later on ApplicationJob" do
    expect_offense(<<~RUBY)
      allow(ApplicationJob).to receive(:perform_all_later)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid stubbing `perform_all_later` on `ApplicationJob` as it silences the runtime uniqueness guard.
    RUBY
  end

  it "registers an offense when expecting perform_all_later on ApplicationJob" do
    expect_offense(<<~RUBY)
      expect(ApplicationJob).to have_received(:perform_all_later)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid stubbing `perform_all_later` on `ApplicationJob` as it silences the runtime uniqueness guard.
    RUBY
  end

  it "registers an offense when negatively expecting perform_all_later on ApplicationJob" do
    expect_offense(<<~RUBY)
      expect(ApplicationJob).not_to have_received(:perform_all_later)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid stubbing `perform_all_later` on `ApplicationJob` as it silences the runtime uniqueness guard.
    RUBY
  end

  it "does not register an offense when stubbing perform_all_later on ActiveJob" do
    expect_no_offenses(<<~RUBY)
      allow(ActiveJob).to receive(:perform_all_later)
    RUBY
  end

  it "does not register an offense when stubbing other methods on ApplicationJob" do
    expect_no_offenses(<<~RUBY)
      allow(ApplicationJob).to receive(:perform_later)
    RUBY
  end
end
