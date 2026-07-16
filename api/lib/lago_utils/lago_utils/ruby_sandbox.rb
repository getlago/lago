# frozen_string_literal: true

module LagoUtils
  module RubySandbox
    def self.run(code)
      LagoUtils::RubySandbox::Runner.new(code).run
    end
  end
end
