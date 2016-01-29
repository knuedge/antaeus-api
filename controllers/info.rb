# The info Controller

# @!group Informational Public Routes

# GET the current version of the application
get '/info/version.json' do
	body({:api => {:version => APP_VERSION}}.to_json)
end

# GET the current status of the application
get '/info/status.json' do
	body({:status => :available}.to_json)
end