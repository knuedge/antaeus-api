# The appointments Controller

api_parse_for(:appointments)

# @!group Guests Private Routes

# GET the upcoming appointments
get '/appointments/upcoming' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch('upcoming_appts_json', expires: 300) do
          Appointment.upcoming.to_json(exclude: [:guest_id], relationships: {guest: {exclude: :pin}})
        end
      )
    else
      fail "Insufficient Privileges"
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
