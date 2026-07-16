# frozen_string_literal: true

RSpec::Matchers.define :contains_xml_node do |xpath|
  match do |document|
    @xpath = xpath
    @node = document.at_xpath(xpath)

    if @node.nil?
      @error = :node_not_found
      return false
    end

    if @node_value && @node.text != @node_value.to_s
      @error = :diff_node_value
      return false
    end

    if @attribute && @attribute_value
      if @node.attributes[@attribute].nil?
        @error = :attribute_not_found
        return false
      elsif @node.attributes[@attribute].value != @attribute_value.to_s
        @error = :diff_attribute_value
        return false
      end
    end

    true
  end

  chain :with_value do |value|
    @node_value = value
  end

  chain :with_attribute do |attribute, value|
    @attribute = attribute
    @attribute_value = value
  end

  failure_message do |document|
    case @error
    when :node_not_found
      "expected XPath \"#{@xpath}\" to be present, but it was not found in the XML"
    when :diff_node_value
      "expected XPath \"#{@xpath}\" to have value \"#{@node_value}\", but was \"#{@node.text}\""
    when :attribute_not_found
      "expected XPath \"#{@xpath}\" to have attribute \"#{@attribute}\", but attribute was not found"
    when :diff_attribute_value
      "expected XPath \"#{@xpath}\" to have attribute \"#{@attribute}\" equals to \"#{@attribute_value}\", but was \"#{@node[@attribute]}\""
    end
  end
end

RSpec::Matchers.define :contains_xml_comment do |comment|
  match do |document|
    document.xpath("//comment()").map(&:text).include?(comment)
  end
end
