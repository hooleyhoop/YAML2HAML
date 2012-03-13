require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'psych'

require_relative 'src/hoo_util'
require_relative 'src/hoo_renderer'

set :environment, :development
set :haml, :format => :html5 # default Haml format is :xhtml
#set :root, File.dirname(__FILE__)

configure :development do |config|
  require "sinatra/reloader"
  config.also_reload( File.join( File.dirname(__FILE__), "src/*.rb" ) )
  set :my_option, "world"               #settings.my_option
  @my_variable="world"
  @@ahem = 'bnjo'
end


# Constants - just directory names
views_directory = File.join( File.dirname(__FILE__), 'views' )
template_directory = File.join( views_directory, 'haml_templates' )
page_directory = File.join( views_directory, 'yaml_pages' ) 

get '/' do

  test_yaml_hash = Psych.load_file( File.join( page_directory, 'index.yaml' ) )  
  test_yaml_hash = HooUtil.symbolize_keys( test_yaml_hash )

  unique_keys = Set.new
  HooUtil.uniqueKeys( test_yaml_hash, unique_keys )

  template_keys = HooUtil.keysStartingWith( unique_keys, '_' )
  
  template_paths_hash = HooUtil.buildTemplatePathsForKeys( template_directory, template_keys )
  engine_hash = HooUtil.buildTemplateEngines( template_paths_hash )

  root_renderer = HooUtil.buildViewHierarchy( test_yaml_hash, engine_hash )
  return root_renderer.render
end


  #puts YAML::dump(engine_hash)

  #puts "#Loaded yaml> #{test_yaml_hash.inspect}"
  #puts YAML::dump(test_yaml_hash)
  
  #isFile = File.file?( test_haml_file ) 
  #raise "test file not found" if isFile==false

  #test1_haml_file_path = File.join( template_directory, 'test1.haml' )
  #test2_haml_file_path = File.join( template_directory, 'test2.haml' )
  #test3_haml_file_path = File.join( template_directory, 'test3.haml' )
  
  #test1_file_string = IO.read( test1_haml_file_path )
  #test2_file_string = IO.read( test2_haml_file_path )
  #test3_file_string = IO.read( test3_haml_file_path )

  #inner1_html = Haml::Engine.new( test2_file_string ).render()
  #inner2_html = Haml::Engine.new( test3_file_string ).render()
  
  #root_html = Haml::Engine.new( test1_file_string ).render {
  #  inner1_html
  #}
  #root_html + root_html
