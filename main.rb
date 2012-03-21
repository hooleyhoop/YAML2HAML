require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'psych'
require 'pp'

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
def renderYAML( page_name )

  yaml_hash_or_array = loadYAMLNamed( page_name, settings.page_directory )

  renderer_hierachy = buildRendererHierarchyFromYAML( yaml_hash_or_array )
  puts YAML::dump(renderer_hierachy)

  unique_template_keys = Set.new()
  uniqueTemplateKeys( renderer_hierachy, unique_template_keys )

  return 'nothing to render' if unique_template_keys.length ==0
  
  # build a hash :template_name => haml.engine
  template_paths_hash = buildTemplatePathsForKeys( settings.template_directory, unique_template_keys )
  engine_hash = buildTemplateEngines( template_paths_hash )

  installRenderEngines( renderer_hierachy, engine_hash )
  
  return renderer_hierachy.render_the_engine( self )
end

#
def renderHAML( page_name )

  found_file = assertSingleFile( Dir.glob("#{settings.template_directory}/**/#{page_name}.haml"), page_name )
  return haml(File.read(found_file))
end

#
def renderPage( page_name )
  $base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"

  ext = File.extname( page_name )
  if ext.nil? == false && ext.length > 0
    page_name_parts = page_name.split(".")
    page_name = page_name_parts[0]
    
    result = case page_name_parts[1]
      when 'yaml'
        return renderYAML( page_name )
      when 'haml'
        return renderHAML( page_name )
    end

  else
    return renderYAML( page_name )
  end
  return "failed to handle #{page_name}#{ext}"
end

# ROUTES

# /public are served automatically?
#get "/css/type.css" do
#  content_type 'text/css'
#  send_file File.expand_path('index.html', settings.public)
#end


get '/:page_name.?/?' do
  renderPage( params[:page_name] )
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

module Haml::Filters::Scss
  include Haml::Filters::Base
  def render(text)
    "<script>#{text}</script>"
  end
end

# ---------------------------------
# Over riding the Javascript filter
# ---------------------------------
#module Haml::Filters::Javascript
#  def render_with_options(text, options)
#    "javascript --> #{text}"
#  end
#end

# ------------------------------
# New Monkey filter, use :monkey
# ------------------------------
module Haml::Filters::Monkey
  include Haml::Filters::Base
  def render(text)
    "<script>#{text}</script>"
  end
end



#puts YAML::dump(engine_hash)
