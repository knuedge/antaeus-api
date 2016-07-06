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

  property :comment,    Text

  # The user that created the appointment
  property :created_by, String, required: true, index: true

  property :created_at, DateTime, index: true
  property :updated_at, DateTime

  belongs_to :guest
  belongs_to :location
  has 1, :guest_checkin
  has 1, :approval

  after :save do |appt|
    cache_expire('upcoming_appointment_json') # need to expire the cache on save
    cache_expire('all_appointment_json')
  end

  after :destroy do |appt|
    cache_expire('upcoming_appointment_json') # need to expire the cache on destroy
    cache_expire('all_appointment_json')
  end

  before :destroy do |appt|
    fail Exceptions::ForbiddenChange if appt.has_checkin?
  end

  # Ensure times are in UTC before they're saved
  def arrival=(time)
    super(Time.parse(time).utc)
  end

  def approved?
    approval ? true : false
  end

  def has_checkin?
    guest_checkin ? true : false
  end

  alias_method :arrived?, :has_checkin?

  def change_approval(status, user)
    fail Exceptions::ForbiddenChange if has_checkin?
    if status
      Approval.new(appointment: self, dn: user.dn).save unless approved?
    else
      approval.destroy if approved?
    end
    cache_expire('upcoming_appointment_json')
    cache_expire('all_appointment_json')
  end

  def checkin(guest_user = nil)
    fail Exceptions::ForbiddenChange unless approved?
    if guest_user
      GuestCheckin.new(appointment: self, guest: guest_user).save
    else
      GuestCheckin.new(appointment: self, guest: self.guest).save
    end
    cache_expire('upcoming_appointment_json')
    cache_expire('all_appointment_json')
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
