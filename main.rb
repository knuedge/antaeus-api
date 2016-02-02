require "rubygems"
require "bundler/setup"

require 'sinatra'
require 'yaml'
require 'json'
require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'
require 'dm-migrations'
require 'dm-serializer'
require 'dm-types'
require 'dm-transactions'
require 'linguistics'
require 'mail-gpg'
require 'net/ldap'
require 'moneta'

### Custom code

# The version of this application
APP_VERSION = '0.0.1'
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
      :groupattr  => 'cn',
      :memberattr => 'memberUid',
      :memberref  => 'attribute',
      :userbase   => 'ou=People,dc=example,dc=com',
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

# Library updates
puts '>> Loading internal libraries'
Dir.glob(File.join(Dir.pwd,'lib/*.rb')).each do |library|
  require library
end

puts '>> Connecting to authentication backend (LDAP)'
LDAP.connect!

# Models
puts '>> Loading models'
Dir.glob(File.join(Dir.pwd,'models/*.rb')).each do |model|
  require model
end

# Finish the data store setup
DataMapper.finalize
DataMapper.auto_upgrade!

# Be sure to always return JSON
before '*' do
  content_type 'application/json'
end

# Controllers
puts '>> Loading API controllers'
Dir.glob(File.join(Dir.pwd,'controllers/*.rb')).each do |controller|
  require controller
end