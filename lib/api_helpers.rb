# API related helpers

## Filters

# Setup a standard parsed @data object
# by parsing the params or request body
def api_parse_for(controller)
  before /\/#{controller.to_s}(\/.*|\.json)?$/ do
    if request.get? or request.delete? or request.options?
      begin
        @data = params.to_hash
      rescue => e
        halt(501, { :error => e.message }.to_json)
      end
    else
      begin
        request.body.rewind
        @data = JSON.parse(request.body.read)
      rescue => e
        halt(400, { :error => "Request must be valid JSON: #{e.message}" }.to_json)
      end
    end
  end
end

## Helpers

# Extract the request headers
# @return [Hash] prettier request headers
def request_headers
  request.env.inject({}) {|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
end

# Check API auth based on the `x-api-token` header
# or based on `x-app-ident`, `x-app-key`, and `x-on-behalf-of` headers
def api_authenticated?(fail_on_error = true)
  data = request_headers
  begin
    if data.has_key?('x_app_ident')
      raise "Missing Application Key" unless data.has_key?('x_app_key')
      @via_application = RemoteApplication.first(:ident => data['x_app_ident'])

      raise "Invalid Remote Application Login" unless @via_application and @via_application.app_key == data['x_app_key']
      @current_user = User.from_login(data['x_on_behalf_of'])
    else
      raise "Missing API Token" unless data.has_key?('x_api_token')

      @current_user = User.from_token(data['x_api_token'])
    end
    raise "Failed Attempt" unless @current_user and (@current_user.api_token.valid_token? or @via_application)
    return true
  rescue => e
    if fail_on_error
      halt(401, { :error => "Authentication Failed: #{e.message}" }.to_json)
    else
      false
    end
  end
end

# Check Guest API auth based on the `x-api-token` header
# or based on `x-app-ident`, `x-app-key`, and `x-on-behalf-of` headers
def guest_authenticated?(fail_on_error = true)
  data = request_headers
  begin
    if data.has_key?('x_app_ident')
      raise "Missing Application Key" unless data.has_key?('x_app_key')
      @via_application = RemoteApplication.first(:ident => data['x_app_ident'])

      raise "Invalid Remote Application Login" unless @via_application and @via_application.app_key == data['x_app_key']
      @current_guest = Guest.first(email: data['x_on_behalf_of'])
    else
      raise "Missing API Token" unless data.has_key?('x_guest_token')

      @current_guest = Guest.from_token(data['x_guest_token'])
    end
    raise "Failed Attempt" unless @current_guest
    return true
  rescue => e
    if fail_on_error
      halt(401, { :error => "Authentication Failed: #{e.message}" }.to_json)
    else
      false
    end
  end
end

# Check if this is a lazy request (meaning whether or not the client wants all available info)
def lazy_request?
  if params.key?('lazy') && (!params['lazy'] || params['lazy'].to_s == 'false')
    false
  else
    true
  end
end

# Formulate a URI for a resource
# @return [String] A guess at the URL for a resource
def api_url(*objects)
  begin
    url = ""
    objects.each do |object|
      url << "/"
      url << object.class.to_s.downcase.en.plural
      url << "/"
      url << object.id.to_s
    end
    url << ".json"
    return url
  rescue => e
    halt(501, { :error => e.message }.to_json)
  end
end

# Generic way to do stuff in *all* controller actions
def api_action(options = {}, &block)
  options[:error_code] ||= 422
  options[:metric_key] ||= "#{request.request_method}.#{request.path_info}"
  begin
    # do something with request.path_info for monitoring
    block.call
  rescue => e
    halt(options[:error_code], { :error => e.message }.to_json)
  end
end  

# Add a capability to the Capabilities hash
def register_capability(capability_heading, data)
  Capabilities.instance[capability_heading] = data
end
