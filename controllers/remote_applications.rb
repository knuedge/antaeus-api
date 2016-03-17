# The remote_applications controller

# Filters
api_parse_for(:remote_applications)

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
# REQUIRED: name, ident (must be between 64 and 255 characters).
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
      raise "Missing application data" unless @data.has_key?('app_name') and @data.has_key?('ident')
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
        raise "Duplicate Remote Application"
      end
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
      raise "Removal of Self Not Permitted" if app == @via_application
      app.destroy
      halt 200
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
        body(app.serialize(:only => [:id, :app_name, :ident, :url, :created_at, :updated_at]))
      else
        halt(404) # Forbidden
      end
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
