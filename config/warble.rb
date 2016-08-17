Warbler::Config.new do |config|
  config.dirs = %w(config controllers lib models exceptions)
  config.includes = FileList["main.rb"]
  config.gems -= ["rails"]
  config.gem_dependencies = true
  # config.webxml.jruby.compat.version = "1.9"
  config.features = ["executable", "compiled"]
end
