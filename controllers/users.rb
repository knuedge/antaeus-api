# The users Controller

## Filters

api_parse_for(:users)

# @!group User Public Actions (no api key required)

# Authenticate and receive and API key.
#
# REQUIRED: login, password
# @example
#  {
#   "login": "jonathan.gnagy@gmail.com",
#   "password": "letmein"
#  }
post '/users/authenticate' do
  begin
    fail "Missing Login" if @data.nil? or !@data.has_key?('login')
    fail "Missing Password" unless @data.has_key?('password')

    @current_user = User.from_login(@data['login'])
    if @current_user && LDAP.test_auth(@current_user.dn, @data['password'])
      @current_user.api_token.replace!
      status 200
      body(
        { 
          api_token: encrypt(@current_user.to_s + ';;;' + @current_user.api_token.value),
          valid_to: @current_user.api_token.valid_to
        }.to_json
      )
    else
      halt(401, { :error => "Authentication Failed" }.to_json)
    end
  rescue => e
    halt(401, { :error => e.message }.to_json)
  end
end

options '/users/authenticate' do
  halt 200
end

# @!group User Private Actions (api key required)

# GET the current version of the application
get '/users' do
  begin
    if api_authenticated?
      status 200
    	body(
        if lazy_request?
          cache_fetch('all_user_json', expires: 900) do
            User.all.serialize(only: :id)
          end
        else
          cache_fetch('full_all_user_json', expires: 900) do
            User.all.serialize
          end
        end
      )
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET a User search
get '/users/search' do
  begin
    if api_authenticated?
      fail "Missing query" unless params['q']
      status 200
    	body(
        if lazy_request?
          cache_fetch("search_user_#{params['q']}_json", expires: 300) do
            User.search(params['q']).serialize(only: User.identity_attribute)
          end
        else
          cache_fetch("full_search_user_#{params['q']}_json", expires: 300) do
            User.search(params['q']).serialize
          end
        end
      )
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the details on a user
get '/users/:name' do
  begin
    if api_authenticated?
      status 200
    	body(User.from_login(params['name']).serialize)
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the group memberships for a user
get '/users/:name/memberships' do
  begin
    if api_authenticated?
      status 200
    	body(User.from_login(params['name']).groups.serialize(only: :id))
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
