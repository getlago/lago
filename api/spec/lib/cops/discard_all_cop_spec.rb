# frozen_string_literal: true

require "cop_helper"

RSpec.describe Cops::DiscardAllCop, :config do
  it "registers an offense when using discard_all" do
    expect_offense(<<~RUBY)
      users.discard_all
      ^^^^^^^^^^^^^^^^^ Avoid using `discard_all`. Use `update_all(deleted_at: Time.current)` instead.
    RUBY
  end

  it "registers an offense when using discard_all on a class" do
    expect_offense(<<~RUBY)
      User.discard_all
      ^^^^^^^^^^^^^^^^ Avoid using `discard_all`. Use `update_all(deleted_at: Time.current)` instead.
    RUBY
  end

  it "registers an offense when using discard_all with a block" do
    expect_offense(<<~RUBY)
      users.where(active: false).discard_all
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using `discard_all`. Use `update_all(deleted_at: Time.current)` instead.
    RUBY
  end

  it "does not register an offense when using update_all" do
    expect_no_offenses(<<~RUBY)
      users.update_all(deleted_at: Time.current)
    RUBY
  end

  it "does not register an offense when using discard (singular)" do
    expect_no_offenses(<<~RUBY)
      user.discard
    RUBY
  end
end
