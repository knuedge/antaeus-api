# An outside application with full control
class RemoteApplication
  include DataMapper::Resource
  include Serializable
  include Workflowable
  extend Hookable

  property :id,         Serial
  property :app_name,   String, length: 4..255, required: true, unique_index: true
  property :ident,      String, length: 64..255, required: true, unique_index: true
  property :app_key,    Text,   required: true
  property :url,        Text,   format: :url
  property :created_at, DateTime
  property :updated_at, DateTime

  after :save do |remote_app|
    trigger(:remote_application_save, remote_app)
  end

  after :destroy do |remote_app|
    trigger(:remote_application_destroy, remote_app)
  end

  register_hook :remote_application_save, :remote_application_destroy

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
