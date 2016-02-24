# The guests table
class Guest
  include DataMapper::Resource

  property :id,         Serial
  property :email,      String,   length: 4..255, required: true, index: true, unique_index: true,
                                  format: :email_address
  property :name,       Text,     required: true, index: true
  property :contact,    String,	  required: true, index: true
  property :arrival,    DateTime, required: true, default: lambda {|x,y| Time.now + (24 * 60 * 60) }, index: :arrival
  property :departure,  DateTime, required: true, default: lambda {|x,y| Time.now + (48 * 60 * 60) }, index: :departure
  property :phone,      String
  property :citizenship, String,  required: true, default: 'USA'
  property :need_nda,   Boolean,  required: true, default: false
  property :need_tcpa,  Boolean,  required: true, default: false
  property :comment,    Text
  # SAN, SFO, or AUS
  property :location,   Enum[ 'SAN', 'SFO', 'AUS' ], required: true, default: 'SAN', index: :location
  property :pin,        String,  required: true, default: lambda {|x,y| encrypt('0000') }
  property :created_at, DateTime
  property :updated_at, DateTime
  
  validates_format_of :pin, :with => /^\d{4,6}$/

  # Decrypt the guest's PIN before returning it
  # @return [String]
  def pin
    decrypt(super)
  end

  # Encrypt the guest's PIN before storing it
  def pin=(data)
    super(encrypt(data))
  end

  # Map a contact to its actual user
  # @return [User]
  def contact
    User.from_dn(dn)
  end
end
