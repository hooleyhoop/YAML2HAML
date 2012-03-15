require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'psych'

require_relative 'src/hoo_renderer'
require_relative 'src/hoo_help'

set :environment, :development
#set :root, File.dirname(__FILE__)

configure :development do |config|
  require "sinatra/reloader"
  config.also_reload( File.join( File.dirname(__FILE__), "src/*.rb" ) )

  # Constants - just directory names
  set :views_directory, File.join( File.dirname(__FILE__), 'views' )

  set :template_directory, File.join( settings.views_directory, 'haml_templates' )
  set :page_directory, File.join( settings.views_directory, 'yaml_pages' )

  set :css_directory, File.join( settings.public_folder, 'css' )
  set :images_directory, File.join( settings.public_folder, 'images' )
  set :javascript_directory, File.join( settings.public_folder, 'javascript' )

  set :scss_directory, File.join( settings.views_directory, 'scss' )  
  set :coffeescript_directory, File.join( settings.views_directory, 'coffeescript' )
end

#
def renderPage( page_name )
  $base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
  
  yaml_hash = loadYAMLNamed( page_name, settings.page_directory )
  yaml_hash = symbolize_keys( yaml_hash )
  
  unique_yaml_keys = Set.new
  uniqueKeys( yaml_hash, unique_yaml_keys )

  return 'nothing to render' if unique_yaml_keys.length ==0
  
  # template keys begin with an underscore
  template_keys = keysStartingWith( unique_yaml_keys, '_' )

  return 'nothing to render' if template_keys.length ==0
  
  # build a hash :template_name => haml.engine
  template_paths_hash = buildTemplatePathsForKeys( settings.template_directory, template_keys )
  engine_hash = buildTemplateEngines( template_paths_hash )

  #TODO: The engine needs access to the global scope, no?

  root_renderer = buildViewHierarchy( yaml_hash, engine_hash )
  return root_renderer.render( self )
end

# ROUTES

# /public are served automatically?
#get "/css/type.css" do
#  content_type 'text/css'
#  send_file File.expand_path('index.html', settings.public)
#end
get '/:page/?' do
  renderPage( params[:page] )
end

get '/' do
  renderPage( 'index' )
end

# Use to test access to helper methods from .erb and haml
helpers do
  def example_global_helper
    msg = "Congratulations, you called a global helper"
    puts msg
    return msg
  end
end

#puts YAML::dump(engine_hash)
