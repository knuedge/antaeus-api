# The guests table
class Guest
  include DataMapper::Resource
  include Serializable

  property :id,         Serial
  property :email,      String,   length: 4..255, required: true, unique_index: true,
                                  format: :email_address
  property :full_name,  String,   required: true, index: true
  property :phone,      String
  property :citizenship, String,  required: true, default: 'USA'
  # Does the guest need an NDA?
  property :need_nda,   Boolean,  required: true, default: false
  property :signed_nda, Boolean,  required: true, default: false
  # Does the guest need a TCP Attachment A?
  property :need_tcpa,  Boolean,  required: true, default: false
  property :signed_tcpa, Boolean,  required: true, default: false

  # Guest's arrival PIN for logging into this system
  property :pin,        Text,    required: true
  property :created_at, DateTime
  property :updated_at, DateTime
  
  validates_format_of :pin, :with => /^\d{4,6}$/

  has n, :appointments

  # Decrypt the guest's PIN before returning it
  # @return [String]
  def pin
    decrypt(super)
  end

  # Encrypt the guest's PIN before storing it
  def pin=(data)
    super(encrypt(data))
  end

  # Just the upcoming appointments
  def upcoming_appointments
    appointments.upcoming
  end

  # Just the available appointments for today for a location
  def available_appointments(location)
    upcoming_appointments.all(location: location, arrival_date: Date.today)
  end
end
