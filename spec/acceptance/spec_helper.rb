# -*- encoding : utf-8 -*-

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'fabrication'
require 'logging'
require 'ashikawa-core'

begin
  require 'debugger'
rescue LoadError
  puts "Debugger is not available. Maybe you're Travis."
end

class Fabrication::Generator::Guacamole < Fabrication::Generator::Base

  def self.supports?(klass)
    defined?(Guacamole) && klass.ancestors.include?(Guacamole::Model)
  end

  def persist
    collection = [_instance.class.name.pluralize, 'Collection'].join.constantize
    collection.save _instance
  end

  def validate_instance
    _instance.valid?
  end

end

Fabrication::Schematic::Definition::GENERATORS.unshift Fabrication::Generator::Guacamole

ENV['GUACAMOLE_ENV'] = 'test'

Guacamole.configure do |config|
  logger = Logging.logger['guacamole_logger']
  logger.add_appenders(
      Logging.appenders.file('log/acceptance.log')
  )
  logger.level = :info

  config.logger = logger

  config.load File.join(File.dirname(__FILE__), 'config', 'guacamole.yml')
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Guacamole.configuration.database.collections.each { |collection| collection.truncate! }
  end
end
