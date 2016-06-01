# The groups Controller

api_parse_for(:groups)
register_capability(:groups, version: APP_VERSION)

# @!group Public Routes

# GET the groups known to the application
get '/groups' do
  api_action do
    if api_authenticated? && @current_user.admin?
      status 200
      body(
        if lazy_request?
          cache_fetch('all_group_json', expires: 300) { Group.all.serialize(only: :id) }
        else
          cache_fetch('full_all_group_json', expires: 300) {
            Group.all.serialize
          }
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET a Group search
get '/groups/search' do
  api_action do
    if api_authenticated? && @current_user.admin?
      status 200
    	body(
        if lazy_request?
          cache_fetch("search_group_#{params['q']}_json", expires: 300) do
            Group.search(params['q']).serialize(only: :id)
          end
        else
          cache_fetch("full_search_group_#{params['q']}_json", expires: 300) do
            Group.search(params['q']).serialize
          end
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET the details on a user
get '/groups/:group' do
  api_action do
    if api_authenticated? && @current_user.admin?
      status 200
    	body(
        Group.from_attr(params['group']).serialize(
          exclude: [ CONFIG[:ldap][:memberattr].to_sym ]
        )
      )
    else
      halt(403) # Forbidden
    end
  end
end

# GET the members of a group
get '/groups/:group/members' do
  api_action do
    if api_authenticated? && @current_user.admin?
      status 200
    	body(
        if lazy_request?
          cache_fetch("group_#{params['group']}_members_json", expires: 120) do
            Group.from_attr(params['group']).members.serialize(only: :id)
          end
        else
          cache_fetch("full_group_#{params['group']}_members_json", expires: 120) do
            Group.from_attr(params['group']).members.serialize(include: :name)
          end
        end
      )
    else
      halt(403) # Forbidden
    end
  end
end
