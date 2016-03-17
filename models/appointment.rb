# The appointments table
class Appointment
  include DataMapper::Resource
  include Serializable

  property :id,         Serial

  # This should be the username of the contact this guest is here to see
  property :contact,    String,	  required: true, index: true

  # This field is normally made for us, but I want a multi-column unique index
  property :guest_id,   Integer, required: true, index: true, unique_index: :ga

  property :arrival,    DateTime, required: true, index: :arrival_time
  property :arrival_date,    Date,  required: true, index: :arrival_date, unique_index: :ga,
                                    default: lambda {|r,p| r.arrival }

  property :departure,  Date, required: true, index: :departure
  # location (SAN, SFO, or AUS) for the guest's visit
  property :location,   String,  required: true, default: 'SAN', index: :location
  property :comment,    Text

  property :created_at, DateTime, index: true
  property :updated_at, DateTime

  belongs_to :guest

  validates_within :location, :set => [ 'SAN', 'SFO', 'AUS' ]

  # Map a contact to its actual user
  # @return [User]
  def user
    User.from_login(contact)
  end

  # Upcoming appointments
  def self.upcoming
    all(:arrival.gt => Time.now)
  end
end
