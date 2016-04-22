require "rubygems"
require "bundler/setup"

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
APP_VERSION = '0.0.2'
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
    :crypto => {
      :passphrase => 'CHANGE-THIS-IMMEDIATELY!'
    },
    :mail => {
      :from  => 'noreply@example.com',
      :relay => 'mail.example.com',
      :port  => 25,
      :gpg   => {
        :sign => false,
        :passphrase => 'CHANGE-THIS-IF-GPG!'
      }
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
      :memberattr => 'memberUid',
      :memberref  => 'attribute',
      :userbase   => 'ou=People,dc=example,dc=com',
      :userobjcl  => 'person',
      :userattr   => 'uid',
      :loginattr  => 'uid',
      :mailattr   => 'mail',
      :snattr     => 'sn',
      :gnattr     => 'givenName',
      :admin_group => 'sgAntaeusAdmins',
      :caching    => {
        :enabled  => false,
        :host     => 'redis.example.com',
        :port     => 6379,
        :passphrase => 'letmein'
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
  # LDAP caching
  Thread.new do
    loop do
      [User, Group].each {|lc| ldap_prefetch(lc) }
      sleep 120
    end
  end

  # MySQL Data caching
  Thread.new do
    loop do
      cache_fetch("upcoming_appointment_json", expires: 300) do
        Appointment.upcoming.serialize
      end
      cache_fetch('all_guests_json', expires: 120) do
        Guest.all.serialize(exclude: :pin)
      end
      sleep 120
    end
  end
end

# Controllers
puts '>> Loading API controllers'
require_all 'controllers/*.rb'
