require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'

require_relative 'src/hoo_util'

set :environment, :development
set :haml, :format => :html5 # default Haml format is :xhtml

configure :development do |config|
    require "sinatra/reloader"
    config.also_reload "src/*.rb"
    set :my_option, "world"             #settings.my_option
    @my_variable="world"
    @@ahem = 'bnjo'
end


views_directory = File.join( File.dirname(__FILE__), 'views' )
template_directory = File.join( views_directory, 'haml_templates' )
page_directory = File.join( views_directory, 'yaml_pages' ) 

test_haml_file = File.join( template_directory, 'test.haml' )
test_yaml_file = File.join( page_directory, 'test.yaml' )

isFile = File.file?( test_haml_file ) 
raise "test file not found" if isFile==false

isFile = File.file?( test_yaml_file ) 
raise "test file not found" if isFile==false

test_file_string = IO.read( test_haml_file )
engine = Haml::Engine.new( test_file_string )
hamlResult = engine.render

puts hamlResult
#set :root, File.dirname(__FILE__)
puts HooUtil.bark

get '/' do
    Haml::Engine.new( test_file_string ).render()
    #"Hello world, it's #{test_file_string}"
end


