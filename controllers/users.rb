# The users Controller

api_parse_for(:users)
register_capability(
  :users,
  version: APP_VERSION,
  attributes: {
    name: CONFIG[:ldap][:userattr],
    mail: CONFIG[:ldap][:mailattr]
  }
)

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
    fail Exceptions::MissingProperty if @data.nil? or !@data.has_key?('login')
    fail Exceptions::MissingProperty unless @data.has_key?('password')

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
  api_action do
    if api_authenticated?
      status 200
    	body(
        if lazy_request?
          cache_fetch('all_user_json', expires: 900) do
            User.all.serialize(only: :id)
          end
        else
          cache_fetch('full_all_user_json', expires: 900) do
            User.all.serialize(include: :display_name)
          end
        end
      )
    end
  end
end

# GET a User search
get '/users/search' do
  api_action do
    if api_authenticated?
      fail Exceptions::MissingQuery unless params['q']
      status 200
    	body(
        if lazy_request?
          cache_fetch("search_user_#{params['q']}_json", expires: 300) do
            User.search(params['q']).serialize(only: User.identity_attribute)
          end
        else
          cache_fetch("full_search_user_#{params['q']}_json", expires: 300) do
            User.search(params['q']).serialize(include: :display_name)
          end
        end
      )
    end
  end
end

# GET the details on a user
get '/users/:name' do
  api_action do
    if api_authenticated?
      status 200
    	body(User.from_login(params['name']).serialize(include: :display_name))
    end
  end
end

# GET the group memberships for a user
get '/users/:name/memberships' do
  api_action do
    if api_authenticated?
      status 200
    	body(User.from_login(params['name']).groups.serialize(only: :id, root: :groups))
    end
  end
end
