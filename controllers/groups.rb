# The groups Controller

# @!group Public Routes

# GET the current version of the application
get '/groups.json' do
	body(Group.all.to_json)
end