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

      puts "Received Report Request: #{@data['q'].inspect}" if debugging?

      appointments = Appointment.all
      @data['q'].each do |prop, query|
        # TODO switch to case
        if prop.to_sym == :between && !query.empty?
          s, e = query.split('..')
          sdate = s ? s : (Date.today - 365).to_s
          edate   = e ? e : Date.today.to_s
          appointments = appointments.all(arrival_date: (Date.parse(sdate)..Date.parse(edate)))
        elsif prop.to_sym == :guest && !query.empty?
          appointments = appointments.all(guest: Guest.all(id: query))
        elsif prop.to_sym == :location && !query.empty?
          appointments = appointments.all(location: Location.all(id: query))
        elsif prop.to_sym == :contact && !query.empty?
          # This could probably be improved...
          appointments = appointments.all(contact: User.search(query))
        end
      end

      reportable_appts = appointments.select {|appt| appt.approved? && appt.arrived? }

      # body should be some kind of appointment JSON
      body( reportable_appts.empty? ? { appointments: [] }.to_json : reportable_appts.serialize )
    else
      halt(403) # Forbidden
    end
  end
end
