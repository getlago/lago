# Tooling Gemfile for the Lago deploy repo.
# Pins the deploy tool so every operator uses the SAME Kamal — no "latest" drift.
#
#   gem install bundler && bundle install
#   bundle exec kamal version   # must print 2.11.0
#
source "https://rubygems.org"

# Exact pin (no ~> ): the deploy gate asserts this is 2.11.0.
gem "kamal", "2.11.0"
