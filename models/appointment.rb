# The appointments table
class Appointment
  include DataMapper::Resource

  property :id,         Serial

  # This should be the username of the contact this guest is here to see
  property :contact,    String,	  required: true, index: true
  property :arrival_date,    Date, required: true, index: :arrival_date, default: lambda {|x,y| Date.today + 2 }
  property :arrival,    DateTime, required: true, index: :arrival_time, default: lambda {|x,y| Time.now }
  property :departure,  Date, required: true, index: :departure, default: lambda {|x,y| Date.today + 2 }
  # location (SAN, SFO, or AUS) for the guest's visit
  property :location,   String,  required: true, default: 'SAN', index: :location
  property :comment,    Text

  property :created_at, DateTime, index: true
  property :updated_at, DateTime

  validates_within :location, :set => [ 'SAN', 'SFO', 'AUS' ]

  belongs_to :guest

  # Allow adding a Time object for arrival
  def arrival=(time)
    arrival_date = Date.parse(time.to_s)
    super(time)
  end

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
