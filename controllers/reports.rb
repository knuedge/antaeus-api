# The reports Controller

api_parse_for(:reports)
register_capability(:reports, version: APP_VERSION)

# POST to produce a list of appointments based on some criteria in the form of a query under the key "q"
# This method should be used in an asynchronous way in a web app given how slow it will be overtime.
post '/reports/generate' do
  api_action do
    if api_authenticated? && @current_user.admin?
      fail Exceptions::MissingQuery unless data.key?['q']
      status 200
      queries = data['q']
      appointments = Appointment.all
      queries.each do |prop, query|
        # TODO switch to case
        if prop == :between
          appointments = appointments.all(arrival_date: query)
        elsif prop == :guest
          appointments = appointments.all(guest: Guest.all(id: query))
        elsif prop == :location
          appointments = appointments.all(location: Location.all(id: query))
        elsif prop == :contact
          appointments = appointments.all(contact: User.all(id: query))
        end
      end
      body(
        appointments.select {|appt| appt.approved? && appt.arrived? }.serialize(include: [:arrived?, :approved?, :departed?])
      )
    else
      halt(403) # Forbidden
    end
  end
end
