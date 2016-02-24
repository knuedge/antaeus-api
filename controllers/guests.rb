# The guests Controller

api_parse_for(:guests)

# @!group Guest Public Routes

# @!group Guests Private Routes

# GET the guests known to the application
get '/guests.json' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch('all_guests_json', expires: 60) do
          Guest.all.to_json 
        end
      )
    else
      fail "Insufficient Privileges"
    end
  rescue => e
    fail e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET a Guest search
get '/guests/search.json' do
  begin
    if api_authenticated?
      status 200
    	body(
        cache_fetch("search_guests_#{params['q']}_json", expires: 60) do
          guests = Guest.all(:name.like => "%#{params['q']}") | Guest.all(:email.like => "%#{params['q']}")
          guests.map {|g| g.to_s }.to_json
        end
      )
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end

# GET the details on a guest
get '/guests/:guest.json' do
  begin
    if api_authenticated?
      status 200
    	body(Guest.first(email: params['guest']).to_json)
    end
  rescue => e
    halt(422, { :error => e.message }.to_json)
  end
end
