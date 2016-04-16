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
  has 1, :guest_checkin

  validates_within :location, :set => [ 'SAN', 'SFO', 'AUS' ]

  after :save do |appt|
    cache_expire('upcoming_appts_json') # need to expire the cache on save
  end

  before :destroy do |appt|
    fail "Exceptions::DestroyCheckedinAppointment" if appt.has_checkin?
  end

  def has_checkin?
    guest_checkin ? true : false
  end

  alias_method :arrived?, :has_checkin?

  def checkin(guest_user = nil)
    if guest_user
      GuestCheckin.new(appointment: self, guest: guest_user).save
    else
      GuestCheckin.new(appointment: self, guest: self.guest).save
    end
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
