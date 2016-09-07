# The reports Controller

api_parse_for(:reports)
register_capability(:reports, version: APP_VERSION)

# POST to produce a list of appointments based on some criteria in the form of a query under the key "q"
# This method should be used in an asynchronous way in a web app given how slow it will be overtime.
post '/reports/generate' do
  api_action do
    if api_authenticated? && @current_user.admin?
      fail Exceptions::MissingQuery unless @data.key?('q')
      status 200

      appointments = Appointment.all
      @data['q'].each do |prop, query|
        # TODO switch to case
        if prop.to_sym == :between
          appointments = appointments.all(arrival_date: query)
        elsif prop.to_sym == :guest
          appointments = appointments.all(guest: Guest.all(id: query))
        elsif prop.to_sym == :location
          appointments = appointments.all(location: Location.all(id: query))
        elsif prop.to_sym == :contact
          appointments = appointments.all(contact: User.all(id: query))
        end
      end
      body(
        if appointments.empty?
          {appointments: []}.to_json
        else
          appointments.select {|appt| appt.approved? && appt.arrived? }.serialize(include: [:arrived?, :approved?, :departed?])
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end
