# The groups Controller

# @!group Public Routes

# GET the current version of the application
get '/users.json' do
	body(User.all.collect {|u| u.dn }.to_json)
end