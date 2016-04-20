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
      fail "Insufficient Privileges"
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
      fail "Insufficient Privileges"
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
