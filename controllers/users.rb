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
post '/users/authenticate.json' do
  begin
    fail "Missing Login" if @data.nil? or !@data.has_key?('login')
    fail "Missing Password" unless @data.has_key?('password')

    @current_user = User.from_login(@data['login'])
    if @current_user && LDAP.test_auth(@current_user.dn, @data['password'])
      @current_user.api_token.replace!
      status 200
      body(
        { 
          api_token: @current_user.api_token.value,
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

# GET the current version of the application
get '/users.json' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch('all_user_json', expires: 900) do
          PooledIterator.collect(User.all, 4) {|u| u.to_s }.to_json 
        end
      )
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET a User search
get '/users/search.json' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch("search_user_#{params['q']}_json", expires: 300) do
          PooledIterator.collect(User.search(params['q']), 6) {|u| u.to_s }.to_json
        end
      )
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the details on a user
get '/users/:name.json' do
  begin
    if api_authenticated?
      status 200
    	body(User.from_login(params['name']).to_json)
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
