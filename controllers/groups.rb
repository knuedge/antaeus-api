# The groups Controller

api_parse_for(:groups)

# @!group Public Routes

# GET the current version of the application
get '/groups.json' do
  begin
    if api_authenticated? && @current_user.admin?
      status 200
    	body(Group.all.collect {|u| u.dn }.to_json)
    else
      fail "Insufficient Privileges"
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end