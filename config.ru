# Require the necessary main.rb file
root = File.dirname(__FILE__)
require File.join(root, 'main.rb')

set :run, false

# deploy httpd server
run Sinatra::Application
