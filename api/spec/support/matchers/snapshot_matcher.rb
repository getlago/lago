# frozen_string_literal: true

# This matcher allows to match an HTML snapshot with the same logic as the `match_snapshot` matcher.
#
# The main difference is that it will add the test context and a `.html` extension to the snapshot name. For instance, if the test is:
#
# ```ruby
# context "when the customer is a company" do
#   let(:customer) { create(:customer, :company) }
#
#   it "renders the invoice" do
#     expect(rendered_template).to match_html_snapshot
#   end
# end
# ```
#
# The snapshot name will be `when_the_customer_is_a_company/renders_the_invoice.html.snap`.
#
# Usage example:
#
# ```
# it "renders the invoice" do
#   expect(rendered_template).to match_html_snapshot
# end
# ```
RSpec::Matchers.define :match_html_snapshot do |name: nil, strip_style: true, strip_head: true|
  match(notify_expectation_failures: true) do |html|
    name = [snapshot_name(RSpec.current_example.metadata), sanitize_fragment(name)].compact.join("/")
    name += ".html"
    html = beautify(html, strip_style: strip_style, strip_head: strip_head)
    expect(html).to match_snapshot(name)
  end

  private

  def sanitize_fragment(fragment)
    return nil if fragment.nil?

    fragment.tr("/", "_").tr(" ", "_")
  end

  def snapshot_name(metadata)
    description = metadata[:description].empty? ? metadata[:scoped_id] : metadata[:description]
    example_group = metadata.key?(:example_group) ? metadata[:example_group] : metadata[:parent_example_group]

    description = sanitize_fragment(description)
    if example_group
      [snapshot_name(example_group), description].join("/")
    else
      description
    end
  end

  def beautify(html, strip_style: true, strip_head: true)
    # Remove unnecessary styles and head tags
    if strip_style
      prev = nil
      while html != prev
        prev = html
        html = html.gsub(%r{<style.*?>.*?</style>}m, "")
      end
    end
    html = html.gsub(%r{<head>.*?</head>}m, "") if strip_head
    # Make sure each HTML start tag is on a new line as the beautifier does not always do it
    html = html.gsub(%r{><([^/])}, ">\n<\\1")
    html = html.gsub(%r{(</.*?>)}, "\\1\n")
    html = html.gsub(%r{/>}, "/>\n")
    # Ensure the HTML string is properly encoded as UTF-8, otherwise we won't be able to write the snapshot
    html = html.force_encoding("UTF-8") if html.encoding != Encoding::UTF_8
    HtmlBeautifier.beautify(html, stop_on_errors: true)
  end
end
