# The guests table
class Guest
  include DataMapper::Resource
  include Serializable
  include Workflowable
  extend Hookable

  property :id,         Serial
  property :email,      String,   length: 4..255, required: true, unique_index: true,
                                  format: :email_address
  property :full_name,  String,   required: true, index: true
  property :phone,      String
  property :citizenship, String,  required: true, default: 'US', length: 2, index: true
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
  property :deleted_at, ParanoidDateTime # this ensures things aren't really deleted
  
  validates_format_of :pin, :with => /^\d{4,6}$/

  has n, :appointments
  has n, :guest_checkins

  after :save do |guest|
    cache_expire('all_guests_json') # need to expire the cache on save
    trigger(:guest_save, guest)
  end

  after :destroy do |guest|
    cache_expire('all_guests_json') # need to expire the cache on destroy
    trigger(:guest_destroy, guest)
  end

  register_hook :guest_save, :guest_destroy

  # Authenticate a Guest from their crafted API token
  # Guest tokens take the lazy way out, since guests are already very limited
  def self.from_token(token)
    begin
      # Guest tokens should be:
      # <guest id>;;;<encrypted PIN>;;;<datestamp>
      gid, real_token, datestamp = decrypt(token).split(';;;')
      # only allow these tokens to be valid for 24 hours (60 * 60 * 24)
      fail 'Expired Token' if (Time.now - Time.parse(datestamp)) > 86400
    rescue => e
      fail 'Invalid Token'
    end

    guest = get(gid)
    if guest.pin.to_s == decrypt(real_token).to_s
      return guest
    else
      fail 'No Matching Token'
    end
  end

  def token
    encrypt [id.to_s, encrypt(pin), Time.now.to_s].join(';;;')
  end

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
