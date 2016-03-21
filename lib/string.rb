require 'base64'

# Monkey-patching the String class to include useful operations
class String
  # Convert a string to a Base64 encoded version of itself
  # @return [String]
  def to_64
    Base64.encode64(self).chomp.gsub("\n", '')
  end

  # Decode a Base64 encoded string
  # @return [String]
  def decode64
    Base64.decode64(self)
  end

  # Convert CamelCase to underscored_text
  # @return [String]
  def to_underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  # Convert underscored_text to CamelCase
  # @return [String]
  def to_camel
    self.split('_').map {|part| part.capitalize}.join
  end
end
