# The locations Controller

api_parse_for(:locations)
register_capability(:locations, version: APP_VERSION)

# @!group Location Private Routes

# GET the locations known to the application
get '/locations' do
  api_action do
    if api_authenticated?
      status 200
    	body(
        cache_fetch('all_locations_json', expires: 120) do
          Location.all.serialize(only: [:id, :shortname, :city, :state, :country])
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET a location search
get '/locations/search' do
  api_action do
    if api_authenticated?
      fail Exceptions::MissingQuery unless params['q']
      status 200
    	body(
        cache_fetch("search_locations_#{params['q']}_json", expires: 60) do
          locs = Location.all(:shortname.like => "%#{params['q']}") | Location.all(:city.like => "%#{params['q']}")
          locs.serialize(only: [:id, :shortname, :city, :state, :country])
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET the details on a guest
get '/locations/:id' do
  api_action do
    if api_authenticated?(false) || guest_authenticated?
      status 200
      body(Location.get(params['id']).serialize)
    else
      halt(403) # Forbidden
    end
  end
end

# POST an new location.
#
# REQUIRED: shortname, city, state, country.
#
# OPTIONAL: address_line1, address_line2, zip, phone, details, public_details, email_instructions.
# @example
#  {
#    "shortname": "SAN",
#    "address_line1": "1234 Science Center Drive",
#    "address_line2": "Suite #567",
#    "city": "San Diego",
#    "state": "California",
#    "zip": "92121",
#    "country": "US",
#    "phone": "+18585559876",
#    "details": "This is not visible to guests",
#    "public_details": "This is visible to a guest",
#    "email_instructions": "<div>Some <i>fancy</i> HTML to deliver to guests</div>"
#  }
post '/locations' do
	api_action do
    if api_authenticated?
      unless @data.key?('shortname') && @data.key?('city') && @data.key?('state') && @data.key?('country')
        fail Exceptions::MissingProperty
      end
      if !Location.first(:shortname => @data['shortname'])
        location = Location.new(
          shortname: @data['shortname'].to_s.upcase,
          city: @data['city'].to_s,
          state: @data['state'].to_s,
          country: @data['country'].to_s
        )

        # Optional values
        location.address_line1 = @data['address_line1'] if @data.key?('address_line1')
        location.address_line2 = @data['address_line2'] if @data.key?('address_line2')
        location.zip = @data['zip'] if @data.key?('zip')
        location.phone = @data['phone'] if @data.key?('phone')
        location.details = @data['details'] if @data.key?('details')
        location.public_details = @data['public_details'] if @data.key?('public_details')
        location.email_instructions = @data['email_instructions'] if @data.key?('email_instructions')

        location.raise_on_save_failure = true
        location.save
        location.reload
        status 201
        body(location.serialize)
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
put '/locations/:id' do
  api_action do
    if api_authenticated?
      location = Location.get(params['id'])

      # Gather a list of the properties we care about
      bad_props = [:updated_at, :created_at, :id]
      props = Location.properties.map(&:name) - bad_props

      # Set all the props sent, ignoring those we don't know about
      props.map(&:to_s).each do |prop|
        location.send("#{prop}=".to_sym, @data[prop]) if @data.key?(prop)
      end

      # Complain if saving fails
      location.raise_on_save_failure = true
      location.save
      halt 204
    else
      halt(403) # Forbidden
    end
  end
end

# DELETE a guest
#
# This action doesn't do anything, for security / retention reasons
delete '/locations/:id' do |location_id|
  api_action do
    if api_authenticated?
      location = Location.get(location_id)
      location.destroy # cascades through dm-constraints
      cache_expire('all_locations_json') # need to expire the cache on deletes
      halt 200
    else
      halt(403) # Forbidden
    end
  end
end

# GET a location's upcoming appointments
#
# REQUIRED: id (via URI)
get '/locations/:id/appointments' do
  api_action do
    if api_authenticated?(false)
      location = Location.get(params['id'])
      status 200
      if params.key?('all') && params['all']
        body(location.appointments.serialize(include: :arrived?))
      else
        body(location.upcoming_appointments.serialize(include: :arrived?))
      end
    else
      halt(403) # Forbidden
    end
  end
end
