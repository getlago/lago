# frozen_string_literal: true

require "cop_helper"

RSpec.describe Cops::ServiceCallCop, :config do
  it "registers an offense when defining call with arguments" do
    expect_offense(<<~RUBY)
      class X < BaseService
        def call(args)
        ^^^^^^^^^^^^^^ Subclasses of Baseservice should have #call without arguments
          super
        end
      end
    RUBY
  end

  it "registers an offense when defining call with keyword arguments" do
    expect_offense(<<~RUBY)
      class X < BaseService
        def call(arg:)
        ^^^^^^^^^^^^^^ Subclasses of Baseservice should have #call without arguments
          super
        end
      end
    RUBY
  end

  it "registers an offense when subclass of ::BaseService" do
    expect_offense(<<~RUBY)
      class X < ::BaseService
        def call(arg:)
        ^^^^^^^^^^^^^^ Subclasses of Baseservice should have #call without arguments
          super
        end
      end
    RUBY
  end

  it "does not register an offense when not a subclass of BaseService" do
    expect_no_offenses(<<~RUBY)
      class X
        def call(arg:)
          super
        end
      end
    RUBY
  end
end
