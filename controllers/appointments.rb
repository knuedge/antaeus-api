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
          Appointment.all.serialize
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
          Appointment.upcoming.serialize
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
      halt 200
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
        body app.serialize
      else
        halt(404) # Forbidden
      end
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
