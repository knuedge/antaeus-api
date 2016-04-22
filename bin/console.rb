#!/usr/bin/env ruby
#
# A console to experiment / troubleshoot antaeus-api

require "rubygems"
require "bundler/setup"

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

require 'net/ldap'
require 'moneta'

puts ">> Starting console..."

# Load the config
apprc_dir   = File.expand_path(File.join("~", ".antaeus"))
config_file = File.expand_path(File.join(apprc_dir, "api.yml"))
CONFIG = YAML.load_file(config_file)
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

begin
  require 'pry'
  pry
rescue LoadError => e
  require 'irb'
  IRB.start
end
