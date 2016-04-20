# The appointments Controller

api_parse_for(:appointments)

# @!group Guests Private Routes

# GET the all appointments
#  *Not lazy*
get '/appointments' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch('all_appointment_json', expires: 300) do
          Appointment.all.serialize(include: :arrived?)
        end
      )
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the upcoming appointments
#  *Not lazy*
get '/appointments/upcoming' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch('upcoming_appointment_json', expires: 300) do
          Appointment.upcoming.serialize(include: :arrived?)
        end
      )
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# POST an new appointment.
#
# REQUIRED: contact, guest_id, arrival, departure.
#
# REQUIRED (but include defaults):
#           location (defaults to 'SAN')
#
# OPTIONAL: comment.
# @example
#  {
#    "contact": "jgnagy",
#    "guest_id": "99",
#    "arrival": "2016-02-25T17:08:00-08:00",
#    "departure": "2016-02-25T17:17:00-08:00",
#    "location": "SAN",
#    "comment": "A contractor with Acme Inc."
#  }
post '/appointments' do
	begin
    if api_authenticated?
      unless @data.key?('contact') && @data.key?('guest_id') && @data.key?('arrival') && @data.key?('departure')
        fail Exceptions::MissingProperty
      end

      appt = Appointment.new(
        contact: @data['contact'],
        guest_id: @data['guest_id'],
        arrival: @data['arrival'],
        departure: @data['departure']
      )

      # Important values
      appt.location = @data['location'] if @data.key?('location')

      # Optional values
      appt.comment = @data['comment'] if @data.key?('comment')

      appt.raise_on_save_failure = true
      appt.save
      appt.reload
      status 201
      body(appt.serialize(include: :arrived?))
    else
      halt(403) # Forbidden
    end
	rescue => e
		halt(422, { :error => e.message }.to_json)
	end
end

# PUT an update to a appointments
#
# All keys are optional, but the id can not be changed
put '/appointments/:id' do
  begin
    if api_authenticated?
      if @data.key?('id') && @data['id'].to_s != params['id'].to_s
        fail Exceptions::ForbiddenChange
      end
      appt = Appointment.get(params['id'])

      # Gather a list of the properties we care about
      bad_props = [:updated_at, :created_at, :id]
      props = Appointment.properties.map(&:name) - bad_props

      # Set all the props sent, ignoring those we don't know about
      props.map(&:to_s).each do |prop|
        appt.send("#{prop}=".to_sym, @data[prop]) if @data.key?(prop)
      end

      # Complain if saving fails
      appt.raise_on_save_failure = true
      appt.save
      halt 204
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# DELETE an appointment
delete '/appointments/:id' do |id|
  begin
    if api_authenticated?
      # TODO notify the owner of an appointment
      app = Appointment.get(id)
      app.destroy
      halt 204
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the info about an appointment
get '/appointments/:id' do |id|
  begin
    if api_authenticated?
      app = Appointment.get(id)
      if app
        status 200
        body app.serialize(include: :arrived?)
      else
        halt(404) # Can't find what you're looking for
      end
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# PATCH a check-in for an appointment
#
# REQUIRED: email
# @example
#  {
#   "email": "jgnagy@example.com"
#  }
patch '/appointments/:id/checkin' do |id|
  begin
    app = Appointment.get(id)
    if api_authenticated?(false) || (guest_authenticated? && app.guest == @current_guest)
      if @current_guest
        app.checkin(@current_guest)
      else
        app.checkin(Guest.first(email: @data['email']))
      end
    else
      halt(403) # Forbidden
    end
    halt(204)
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
