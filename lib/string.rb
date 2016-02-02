require 'base64'
# Extending the String class to include Base64 operations
class String
  # Convert a string to a Base64 encoded version of itself
  # @return [String]
  def to_64
    Base64.encode64(self)
  end

  # Decode a Base64 encoded string
  # @return [String]
  def decode64
    Base64.decode64(self)
  end
end
