# The hooks controller

# Filters
api_parse_for(:hooks)
register_capability(:hooks, version: APP_VERSION)

# GET all configured hooks
get '/hooks' do
  api_action do
    if api_authenticated? and @current_user.admin?
      status 200
      body(WorkflowHook.all.serialize(root: :hooks))
    end
  end
end

# GET all available hooks
get '/hooks/available' do
  api_action do
    if api_authenticated? and @current_user.admin?
      status 200
      body(AvailableHooks.instance.serialize(root: :available_hooks))
    end
  end
end

# POST an new hook registration.
#
# REQUIRED: name, plugins
#
# OPTIONAL: configurations
#
# @example
#  {
#    "name": "appointment_checkin",
#    "plugins": ["mail"],
#    "configurations": {
#      "mail": {
#        "from": "antaeus@example.com",
#        "to": "<%= object.guest.email %>, <%= object.contact.email %>",
#        "message": "<%= object.guest.name %> has checked in for their appointment."
#      }
#    }
#  }
post '/hooks' do
	api_action do
    if api_authenticated? and @current_user.admin?
      fail Exceptions::MissingProperty unless @data.has_key?('name') and @data.has_key?('plugins')
      if !WorkflowHook.first(:name => @data['name'])
        wfhook = WorkflowHook.new(
          :name => @data['name'],
          :plugins => @data['plugins']
        )
        wfhook.configurations = @data['configurations'] if @data.has_key?('configurations')
        wfhook.raise_on_save_failure = true
        wfhook.save
        wfhook.reload
        status 201
        body(wfhook.serialize(root: :hook))
      else
        fail Exceptions::DuplicateResource
      end
    else
      halt(403) # Forbidden
    end
	end
end

# PUT an update to a hook
#
# All keys are optional, but the id can not be changed
put '/hooks/:id' do
  api_action do
    if api_authenticated? and @current_user.admin?
      if @data.key?('id') && @data['id'].to_s != params['id'].to_s
        fail Exceptions::ForbiddenChange
      end
      wfhook = WorkflowHook.get(params['id'])

      # Gather a list of the properties we care about
      bad_props = [:updated_at, :created_at, :id, :name]
      props = WorkflowHook.properties.map(&:name) - bad_props

      # Set all the props sent, ignoring those we don't know about
      props.map(&:to_s).each do |prop|
        wfhook.send("#{prop}=".to_sym, @data[prop]) if @data.key?(prop)
      end

      # Complain if saving fails
      wfhook.raise_on_save_failure = true
      wfhook.save
      halt 204
    else
      halt(403) # Forbidden
    end
  end
end

# DELETE a hook registration
delete '/hooks/:id' do |id|
  api_action do
    if api_authenticated? and @current_user.admin?
      wfhook = WorkflowHook.get(id)
      fail Exceptions::ForbiddenChange unless wfhook
      wfhook.destroy
      halt 204
    else
      halt(403) # Forbidden
    end
  end
end

# GET the info about a hook
get '/hooks/:id' do |id|
  api_action do
    if api_authenticated? and @current_user.admin?
      wfhook = WorkflowHook.get(id)
      if wfhook
        status 200
        body(wfhook.serialize(root: :hook))
      else
        halt(404) # Can't find it
      end
    else
      halt(403) # Forbidden
    end
  end
end
