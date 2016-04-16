# The guest_checkins table
class GuestCheckin
  include DataMapper::Resource
  include Serializable

  property :id,         Serial
  property :created_at, DateTime
  property :updated_at, DateTime
  property :deleted_at, ParanoidDateTime # this ensures things aren't really deleted

  belongs_to :appointment
  belongs_to :guest
end
