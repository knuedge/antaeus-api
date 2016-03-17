# The info Controller

# @!group Informational Public Routes

# GET the current version of the application
get '/info/version' do
	body({:api => {:version => APP_VERSION}}.to_json)
end

# GET the current status of the application
get '/info/status' do
	body({:api => {:status => :available}}.to_json)
end
