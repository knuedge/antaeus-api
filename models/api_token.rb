class ApiToken
  include DataMapper::Resource
  
  property :id, 			      Serial
  property :dn,             String,   :length => 4..255, :required => true, :index => :dn, :unique_index => true
  property :value,          Text,     :required => true, :default => create_api_key(Time.now.to_i)
  property :valid_from,   	DateTime,	:required => true, :default => DateTime.now
  property :created_at,     DateTime
  property :updated_at,     DateTime
  
  # Decrypt token before displaying it
  # @return [String]
  def value
    decrypt(super)
  end

  # Encrypt token before storing it
  def value=(data)
    super(encrypt(data))
  end

  # Map a token to its user
  # @return [User]
  def user
    User.from_dn(dn)
  end

  # Check if the API key is still current
  # @return [Boolean]
  def valid_token?
    if Time.now <= valid_from.to_time + (60 * 60)
      validate
      return true
    else
      return false
    end
  end

  # When does the API key expire for this user
  # @return [DateTime]
  def valid_to
    valid_from + (1.0/24.0)
  end

  # Add life to the API key
  # @return [true]
  def validate
    self.valid_from = DateTime.now
    save
    reload
  end

  # Ensure the token a working API key.
  # Either call {#validate} if {#valid?} returns `true`
  # or generate a new API key for the user and replace the expired key.
  # @return [true]
  # @see #valid?
  # @see #validate
  def replace!
    unless valid_token?
      self.value = create_api_key(dn + Time.now.to_i.to_s)
      self.valid_from = DateTime.now
      save
      reload
    end
  end
end