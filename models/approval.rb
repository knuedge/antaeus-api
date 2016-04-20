class Approval
  include DataMapper::Resource
  include Serializable

  property :id,         Serial
  property :dn,         String,   length: 4..255, required: true, index: true
  property :created_at, DateTime
  property :updated_at, DateTime
  property :deleted_at, ParanoidDateTime # this ensures things aren't really deleted

  belongs_to :appointment

  # Map an Approval to its user
  # @return [User]
  def user
    User.from_dn(dn)
  end

  def user=(user_or_dn)
    if user_or_dn.is_a?(User)
      dn = user_or_dn.dn
    else
      dn = user_or_dn
    end
  end
end
