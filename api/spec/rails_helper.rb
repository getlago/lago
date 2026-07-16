# frozen_string_literal: true

def pp(*args)
  # Uncomment the following line if you can't find where you left a `pp` call
  # ap caller.first
  args.each do |arg|
    ap arg, {sort_vars: false, sort_keys: false, indent: -2}
  end
end

# rubocop:disable Rails/Output
def pps(*args)
  pp "--------------------------------------"
  pp(*args)
  pp "--------------------------------------"
end
# rubocop:enable Rails/Output
