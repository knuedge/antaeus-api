require 'crypt/blowfish'
require 'digest/sha2'

CRYPTO = Crypt::Blowfish.new(CONFIG[:crypto][:passphrase])

CRYPTO.freeze

# Encrypt a string, returning a Base64 encoded RSA public-key-encrypted string
# @return [String] Base64 encoded RSA output
def encrypt(string)
  CRYPTO.encrypt_string(string).to_64
end

# Decrypt a Base64 encoded encrypted string, returning the orignal text
# @return [String] unencrypted secret string
# @see #encrypt
def decrypt(encrypted_string)
  CRYPTO.decrypt_string(encrypted_string.decode64)
end

# Create a Base64 encoded SHA512 hash digest of a string
# This is one-way encryption, mostly for password hashing
# @todo add salt
# @return [String] Base64 encoded SHA512 digest
def sha512(string)
  Digest::SHA512.digest(string).to_64.chomp
end

# Create a sufficiently unique and random API key for a user
# This is a one-way hash, encrypted only to make it longer
# @return [String] Base64 encoded secret string
def create_api_key(string, pepper = rand(9**99).to_s)
  # Hash then encrypt our seed string
  10.times do
    # Run our string through 10 rounds of SHA512, each time "peppering" it with random data
    10.times do
      string = sha512(string.to_s + pepper)
    end
    # Encrypt the end result to further obfuscate things
    string = encrypt(string + pepper).gsub("\n", '')
  end
  return string[0...32] # return the end result, stripping to 32 characters
end

# Create a sufficiently unique and random application key
# This is a one-way hash, encrypted only to make it longer
# @return [String] Base64 encoded secret string
def create_app_key(string, pepper = rand(9**99).to_s)
  # Hash then encrypt our seed string
  10.times do
    # Run our string through 10 rounds of SHA512, each time "peppering" it with random data
    10.times do
      string = sha512(string + pepper)
    end
    # Encrypt the end result to further obfuscate things
    string = encrypt(string + pepper).gsub("\n", '')
  end
  return string[0...128] # return the end result, stripping to 128 characters
end