# An outside application with full control
class RemoteApplication
  include DataMapper::Resource
  
  property :id, 			      Serial
  property :name,           String, :length => 4..255, :required => true, :index => :app_name, :unique_index => true
  property :ident,          String, :length => 64..255, :required => true, :index => :app_ident, :unique_index => true
  property :app_key,        Text,   :required => true
  property :url,			      Text,   :format => :url
  property :created_at,     DateTime
  property :updated_at,     DateTime
  
  # Decrypt app_key before displaying it
  # @return [String]
  def app_key
    decrypt(super)
  end

  # Encrypt app_key before storing it
  def app_key=(data)
    super(encrypt(data))
  end
end