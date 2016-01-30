# The groups Controller

# @!group Public Routes

# GET the current version of the application
get '/groups.json' do
  begin
    if api_authenticated?
      status 200
    	body(Group.all.collect {|u| u.dn }.to_json)
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end