# The info Controller

# @!group Informational Public Routes

# GET the current version of the application
get '/info/version' do
  api_action do
	  body({api: {:version => APP_VERSION}}.to_json)
  end
end

# GET the current status of the application
get '/info/status' do
  api_action do
	  body({api: {:status => :available}}.to_json)
  end
end

# TODO: define more capabilities throughout and report on them here
get '/info/capabilities' do
  api_action do
    body({api: {capabilities: Capabilities.instance.to_hash}}.to_json)
  end
end
