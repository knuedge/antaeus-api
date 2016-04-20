# The remote_applications controller

# Filters
api_parse_for(:remote_applications)
register_capability(:remote_applications, version: APP_VERSION)

# TODO: searching

# @!group Remote App Private (authenticated) Actions

# GET all remote applications
get '/remote_applications' do
  begin
    if api_authenticated?
      status 200
      body(RemoteApplication.all.serialize(:only => [:id, :app_name, :url, :created_at]))
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# POST an new remote application registration.
#
# REQUIRED: app_name, ident (must be between 64 and 255 characters).
#
# OPTIONAL: url.
# @example
#  {
#    "app_name": "A Web Frontend",
#    "ident": "mt4Myjc7YRcs3pLZY4Myt2LEUEARjOV60VXSEfbBG5w08l/qJ+KfP7bIcSn/rV0S",
#    "url": "https://antaeus.myawesomesite.com/"
#  }
post '/remote_applications' do
	begin
    if api_authenticated? and @current_user.admin?
      fail Exceptions::MissingProperty unless @data.has_key?('app_name') and @data.has_key?('ident')
      if !RemoteApplication.first(:name => @data['name'])
        app = RemoteApplication.new(
          :app_name => @data['app_name'],
          :ident => @data['ident']
        )
        app.url = @data['url'] if @data.has_key?('url')
        app.app_key = create_app_key(app.ident.to_s[0..63])
        app.raise_on_save_failure = true
        app.save
        app.reload
        status 201
        body(app.serialize) # returns sensitive info
      else
        fail Exceptions::DuplicateResource
      end
    else
      halt(403) # Forbidden
    end
	rescue => e
		halt(422, { :error => e.message }.to_json)
	end
end

# PUT an update to a remote application
#
# All keys are optional, but the id can not be changed
put '/remote_applications/:id' do
  begin
    if api_authenticated? and @current_user.admin?
      if @data.key?('id') && @data['id'].to_s != params['id'].to_s
        fail Exceptions::ForbiddenChange
      end
      app = RemoteApplication.get(params['id'])

      # TODO check if app_key is passed and check it for sufficient complexity
      # For now, just ignore the key below if it is passed in

      # Gather a list of the properties we care about
      bad_props = [:updated_at, :created_at, :id, :app_key]
      props = RemoteApplication.properties.map(&:name) - bad_props

      # Set all the props sent, ignoring those we don't know about
      props.map(&:to_s).each do |prop|
        app.send("#{prop}=".to_sym, @data[prop]) if @data.key?(prop)
      end

      # Complain if saving fails
      app.raise_on_save_failure = true
      app.save
      halt 204
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# DELETE a remote application registration
delete '/remote_applications/:id' do |id|
  begin
    if api_authenticated? and @current_user.admin?
      app = RemoteApplication.get(id)
      fail Exceptions::ForbiddenChange if app == @via_application
      app.destroy
      halt 204
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the info about a remote application
get '/remote_applications/:id' do |id|
  begin
    if api_authenticated? and @current_user.admin?
      app = RemoteApplication.get(id)
      if app
        status 200
        body(app.serialize)
      else
        halt(404) # Can't find it
      end
    else
      halt(403) # Forbidden
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
