# The locations table
class Location
  include DataMapper::Resource
  include Serializable

  property :id,         Serial

  # Short name for a location
  property :shortname,  String,	  length: 3, required: true, unique_index: true

  # Address fields
  property :address_line1, String
  property :address_line2, String
  property :city,          String, required: true, index: true
  property :state,         String, required: true, index: true
  property :zip,           String
  property :country,       String, required: true, default: 'US', length: 2, index: true
  property :phone,         String

  # Any additional details
  property :details, Text

  # Any guest-visible details
  property :public_details, Text

  # details provided in email invites
  property :email_instructions, Text

  property :created_at, DateTime, index: true
  property :updated_at, DateTime
  property :deleted_at, ParanoidDateTime # this ensures things aren't really deleted

  has n, :appointments

  after :save do |loc|
    cache_expire('all_locations_json') # need to expire the cache on save
  end

  before :destroy do |loc|
    appointments.destroy
  end

  after :destroy do |loc|
    cache_expire('all_locations_json') # need to expire the cache on destroy
  end

  # Ensure shortnames are uppercase
  def shortname=(name)
    super(name.to_s.upcase)
  end

  # Upcoming appointments
  def upcoming_appointments
    appointments.upcoming
  end
end
