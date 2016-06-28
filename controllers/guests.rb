# The guests Controller

api_parse_for(:guests)
register_capability(:guests, version: APP_VERSION)

# @!group Guest Public Routes

# Login a Guest.
#
# REQUIRED: email, pin
# @example
#  {
#   "email": "jgnagy@example.com",
#   "pin": "12345"
#  }
post '/guests/login' do
  begin
    fail Exceptions::MissingProperty if @data.nil? or !@data.key?('email')
    fail Exceptions::MissingProperty unless @data.key?('pin')

    guest = Guest.first(email: @data['email'])
    if guest && guest.pin.to_s == @data['pin'].to_s
      status 200
      token = guest.token
      valid_until = decrypt(token).split(';;;')[2]
      body(
        {
          guest_token: guest.token,
          valid_to: valid_until
        }.to_json
      )
    else
      halt(401, { :error => "Login Failed" }.to_json)
    end
  rescue => e
    halt(401, { :error => e.message }.to_json)
  end
end

options '/guests/login' do
  halt 200
end

# @!group Guests Private Routes

# GET the guests known to the application
get '/guests' do
  api_action do
    if api_authenticated?
      status 200
    	body(
        cache_fetch('all_guests_json', expires: 120) do
          Guest.all.serialize(exclude: :pin)
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET a Guest search
get '/guests/search' do
  api_action do
    if api_authenticated?
      fail Exceptions::MissingQuery unless params['q']
      status 200
    	body(
        cache_fetch("search_guests_#{params['q']}_json", expires: 60) do
          guests = Guest.all(:name.like => "%#{params['q']}") | Guest.all(:email.like => "%#{params['q']}")
          guests.serialize(only: [:id, :email, :name])
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET the details on a guest
get '/guests/:id' do
  api_action do
    if api_authenticated?(false) || (guest_authenticated? && @current_guest.id == params['id'])
      status 200
    	body(Guest.get(params['id']).serialize(exclude: :pin))
    else
      halt(403) # Forbidden
    end
  end
end

# POST an new guest.
#
# REQUIRED: email, full_name, pin.
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
	api_action do
    if api_authenticated?
      unless @data.key?('email') && @data.key?('full_name') && @data.key?('pin')
        fail Exceptions::MissingProperty
      end
      if !Guest.first(:email => @data['email'])
        guest = Guest.new(
          email: @data['email'],
          full_name: @data['full_name'],
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
        fail Exceptions::DuplicateResource
      end
    else
      halt(403) # Forbidden
    end
	end
end

# PUT an update to a guest
#
# All keys are optional, but the id can not be changed
put '/guests/:id' do
  api_action do
    if api_authenticated?(false) || (guest_authenticated? && @current_guest.id == params['id'])
      if @data.key?('id') && @data['id'].to_s != params['id'].to_s
        fail Exceptions::ForbiddenChange
      end
      guest = Guest.get(params['id'])

      # Gather a list of the properties we care about
      bad_props = [:updated_at, :created_at, :id]
      props = Guest.properties.map(&:name) - bad_props

      # Set all the props sent, ignoring those we don't know about
      props.map(&:to_s).each do |prop|
        guest.send("#{prop}=".to_sym, @data[prop]) if @data.key?(prop)
      end

      # Complain if saving fails
      guest.raise_on_save_failure = true
      guest.save
      halt 204
    else
      halt(403) # Forbidden
    end
  end
end

# DELETE a guest
#
# This action doesn't do anything, for security / retention reasons
delete '/guests/:id' do |guest_id|
  api_action do
#    if api_authenticated?
#      guest = Guest.get(guest_id)
#      guest.destroy # cascades through dm-constraints
#      cache_expire('all_guests_json') # need to expire the cache on deletes
#      halt 200
#    else
      halt(403) # Forbidden
#    end
  end
end

# GET a guest's upcoming appointments
#
# REQUIRED: id (via URI)
get '/guests/:id/appointments' do
  api_action do
    if api_authenticated?(false) || (guest_authenticated? && @current_guest.id == params['id'])
      guest = Guest.get(params['id'])
      status 200
      if params.key?('all') && params['all']
        body(guest.appointments.serialize(include: :arrived?))
      else
        body(guest.upcoming_appointments.serialize(include: :arrived?))
      end
    else
      halt(403) # Forbidden
    end
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
  api_action do
    if api_authenticated?
      unless @data.key?('arrival') && @data.key?('departure') && @data.key?('contact')
        fail Exceptions::MissingProperty
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
        if @data.key?('location')
          appt.location = Location.first_or_create(shortname: @data['location'].to_s.upcase)
        elsif @data.key?('location_id')
          appt.location = Location.get(@data['location_id'])
        else
          fail Exceptions::MissingProperty
        end

        # Optional values
        appt.comment = @data['comment'] if @data.key?('comment')

        appt.raise_on_save_failure = true
        appt.save
        appt.reload

        status 201
        body(appt.serialize)
      else
        fail "Invalid guest id #{params['id']}"
      end
    else
      halt(403) # Forbidden
    end
  end
end
