# The guests Controller

api_parse_for(:guests)

# @!group Guest Public Routes

# Verify a Guest.
#
# REQUIRED: email, pin
# @example
#  {
#   "email": "jgnagy@intellisis.com",
#   "pin": "12345"
#  }
post '/guests/verify' do
  begin
    fail "Missing Email" if @data.nil? or !@data.key?('email')
    fail "Missing PIN" unless @data.key?('pin')

    guest = Guest.first(email: @data['email'])
    if guest && guest.pin.to_s == @data['pin'].to_s
      status 200
      body(guest.serialize(exclude: :pin, include: [:available_appointments]))
    else
      halt(401, { :error => "Verification Failed" }.to_json)
    end
  rescue => e
    halt(401, { :error => e.message }.to_json)
  end
end



# @!group Guests Private Routes

# GET the guests known to the application
get '/guests' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch('all_guests_json', expires: 120) do
          Guest.all.serialize(exclude: :pin)
        end
      )
    else
      fail "Insufficient Privileges"
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET a Guest search
get '/guests/search' do
  begin
    if api_authenticated?
      fail "Missing query" unless params['q']
      status 200
    	body(
        cache_fetch("search_guests_#{params['q']}_json", expires: 60) do
          guests = Guest.all(:name.like => "%#{params['q']}") | Guest.all(:email.like => "%#{params['q']}")
          guests.serialize(only: [:email, :name])
        end
      )
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the details on a guest
get '/guests/:id' do
  begin
    if api_authenticated?
      status 200
    	body(Guest.get(params['id']).serialize(exclude: :pin))
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# POST an new guest.
#
# REQUIRED: email, name, pin.
#
# REQUIRED (but include defaults):
#           citizenship (defaults to 'USA')
#           need_nda (defaults to `false`)
#           need_tcpa (defaults to `false`)
#
# OPTIONAL: phone, comment.
# @example
#  {
#    "email": "user.name@example.com",
#    "full_name": "User Name",
#    "phone": "+18585551234",
#    "citizenship": "USA",
#    "need_nda": false,
#    "need_tcpa": false,
#    "pin": "12345",
#    "comment": "A contractor with Acme Inc."
#  }
post '/guests' do
	begin
    if api_authenticated?
      unless @data.key?('email') && @data.key?('full_name') && @data.key?('pin')
        fail "Missing required data"
      end
      if !Guest.first(:email => @data['email'])
        guest = Guest.new(
          email: @data['email'],
          name: @data['full_name'],
          pin: @data['pin'].to_s
        )

        # Important values
        guest.citizenship = @data['citizenship'] if @data.key?('citizenship')
        guest.need_nda = @data['need_nda'] if @data.key?('need_nda')
        guest.need_tcpa = @data['need_tcpa'] if @data.key?('need_tcpa')

        # Optional values
        guest.phone = @data['phone'] if @data.key?('phone')

        guest.raise_on_save_failure = true
        guest.save
        guest.reload
        status 201
        body(guest.serialize(exclude: :pin))
      else
        fail "Duplicate Guest"
      end
    end
	rescue => e
		halt(422, { :error => e.message }.to_json)
	end
end


# POST an new appointment for a guest.
#
# REQUIRED: id (via URI), arrival, departure, contact.
#
# REQUIRED (but include defaults):
#           location (defaults to 'SAN')
#
# OPTIONAL: comment.
# @example
#  {
#    "contact": "jgnagy",
#    "arrival": "2016-03-14 08:00:00 -0800",
#    "departure": "2016-03-16 18:00:00 -0800",
#    "location": "SAN",
#    "comment": "Here to work with our favorite IT Ruby enthusiast: Jonathan Gnagy"
#  }
post '/guests/:id/appointments' do
  begin
    if api_authenticated?
      unless @data.key?('arrival') && @data.key?('departure') && @data.key?('contact')
        fail "Missing required data"
      end
      guest = Guest.get(params['id'])
      if guest
        appt = Appointment.new(
          contact: @data['contact'],
          departure: @data['departure'],
          guest: guest
        )
        # Important values
        appt.arrival = @data['arrival'] # use the helper to break apart date and time
        appt.location = @data['location'] if @data.key?('location')

        # Optional values
        appt.comment = @data['comment'] if @data.key?('comment')

        appt.raise_on_save_failure = true
        appt.save
        appt.reload

        # expire our cache of appointments
        cache_expire('upcoming_appts_json')

        status 201
        body(appt.serialize)
      else
        fail "Invalid guest id #{params['id']}"
      end
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
