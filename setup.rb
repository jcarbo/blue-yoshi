require 'rubygems'
require 'bundler/setup'

Bundler.require
Dotenv.overload

require 'csv'

Dir[File.join(__dir__, 'lib', '**/*.rb')].each { |file| require file }


