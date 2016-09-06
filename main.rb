require "rubygems"
require "bundler/setup"
require 'time'

require 'sinatra'
require 'concurrent'
require 'yaml'
require 'json'
require 'singleton'
require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'
require 'dm-migrations'
require 'dm-serializer'
require 'dm-types'
require 'dm-transactions'
require 'linguistics'
require 'require_all'
#require 'mail-gpg'
require 'net/ldap'
require 'moneta'

### Custom code

# The version of this application
APP_VERSION = '0.0.5'
APP_VERSION.freeze

puts ">> Starting up..."

# Create or load a config file
apprc_dir   = File.expand_path(File.join("~", ".antaeus"))
config_file = File.expand_path(File.join(apprc_dir, "api.yml"))
if File.readable?(config_file)
  CONFIG = YAML.load_file(config_file)
else
  # The default config
  CONFIG = {
    :db => {
      :adapter   => 'mysql',
      :pool      => 5,
      :host      => 'localhost',
      :database  => 'antaeusdb',
      :username  => 'antaeus',
      :password  => 'secret'
    },
    :mail => {
      :from  => 'noreply@example.com',
      :relay => 'mail.example.com',
      :port  => 25
    },
    :ldap => {
      :host       => 'ldap.example.com',
      :port       => 389,
      :username   => 'uid=user,ou=people,dc=example,dc=com',
      :password   => '1qaz2wsx',
      :basedn     => 'dc=example,dc=com',
      :groupbase  => 'ou=Groups,dc=example,dc=com',
      :groupobjcl => 'groupOfNames',
      :groupattr  => 'cn',
      :groupscope => 'subtree',
      :memberattr => 'memberUid',
      :memberref  => 'attribute',
      :userbase   => 'ou=People,dc=example,dc=com',
      :userobjcl  => 'person',
      :userattr   => 'uid',
      :userscope  => 'subtree',
      :loginattr  => 'uid',
      :mailattr   => 'mail',
      :displayname => 'displayName',
      :admin_group => 'sgAntaeusAdmins'
    },
    :caching    => {
      :enabled  => false,
      :library  => 'redis',
      :host     => 'redis.example.com',
      :port     => 6379,
      :passphrase => 'letmein',
      :expirations => {
        :ldap => 900
      }
    },
    :debug => false
  }

  puts "Writing base config to `#{config_file}`"
  FileUtils.mkdir_p(File.dirname(config_file))
  File.open(config_file, 'w') {|f| f.write(CONFIG.to_yaml) }
  puts "Please edit this config before starting"
  exit 1
end

CONFIG.freeze

# Help with pluralization
Linguistics.use(:en)

# Load DB stuff
if defined? JRUBY_VERSION
  case CONFIG[:db][:adapter]
  when "mysql"
    require 'jdbc/mysql'
    Jdbc::MySQL.load_driver
  else
    raise "Unsupported DB Adapter: #{CONFIG[:db][:adapter]}"
  end
end

# Setup the data store
puts '>> Connecting to the DB'
DataMapper::Logger.new(STDOUT, :debug) if CONFIG[:debug]
DataMapper.setup(:default, CONFIG[:db])

set :environment, :production
set :logging, true
set :show_exceptions, false
set :dump_exceptions, true
set :raise_errors, true
set :protection, except: :http_origin

# Logging
FileUtils.mkdir_p("#{settings.root}/log/")
file = File.new("#{settings.root}/log/rack.log", 'a+')
file.sync = true
use Rack::CommonLogger, file

# Library updates
puts '>> Loading internal libraries'
require_all Dir.glob('lib/*.rb') + Dir.glob('exceptions/*.rb')

# Prepare our Metrics storage
Metrics.prepare
Metrics.register(:counts)

# Plugins
puts '>> Loading plugins'
require_all Dir.glob('lib/plugins/*.rb')

# LDAP
puts '>> Connecting to authentication backend (LDAP)'
LDAP.connect!

# Models
puts '>> Loading models'
require_all 'models/*.rb'

# Finish the data store setup
DataMapper.finalize
DataMapper.auto_upgrade!

# Be sure to always return JSON
before '*' do
  content_type 'application/json'
  headers 'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => [
            'OPTIONS',
            'DELETE',
            'GET',
            'POST',
            'PUT'
          ],
          'Access-Control-Allow-Headers' => [
            'Content-Type',
            'X-API-Token',
            'X-App-Ident',
            'X-App-Key',
            'X-On-Behalf-Of'
          ]
end

# Background workers for caching
unless CACHE_STATUS == :disabled
  puts '>> Warming Cache...'

  ldap_prefetch(User, [:display_name])
  ldap_prefetch(Group)

  cache_fetch('all_appointment_json', expires: 300) do
    Appointment.all.serialize(include: [:arrived?, :approved?])
  end
  cache_fetch('upcoming_appointment_json', expires: 300) do
    Appointment.upcoming.serialize(include: [:arrived?, :approved?])
  end
  cache_fetch('all_guests_json', expires: 120) do
    Guest.all.serialize(exclude: :pin)
  end
  cache_fetch('all_locations_json', expires: 120) do
    Location.all.serialize(only: [:id, :shortname, :city, :state, :country])
  end

  # LDAP caching background thread
  Thread.new do
    loop do
      sleep 60
      ldap_prefetch(User, [:display_name])
      ldap_prefetch(Group)
      sleep 60
    end
  end

  # MySQL Data caching background thread
  Thread.new do
    loop do
      sleep 60
      cache_fetch('all_appointment_json', expires: 300) do
        Appointment.all.serialize(include: [:arrived?, :approved?])
      end
      cache_fetch('upcoming_appointment_json', expires: 300) do
        Appointment.upcoming.serialize(include: [:arrived?, :approved?])
      end
      cache_fetch('all_guests_json', expires: 120) do
        Guest.all.serialize(exclude: :pin)
      end
      cache_fetch('all_locations_json', expires: 120) do
        Location.all.serialize(only: [:id, :shortname, :city, :state, :country])
      end
      sleep 60
    end
  end
end

# Controllers
puts '>> Loading API controllers'
require_all 'controllers/*.rb'

# Say we're ready!
puts '>> Ready for traffic!'
