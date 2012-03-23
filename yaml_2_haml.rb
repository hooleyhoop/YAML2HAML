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
  #puts YAML::dump(renderer_hierachy)

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
def renderHTML( page_name )
  File.read(File.join('public', "#{page_name}.html"))
end

#
def renderPage( page_name )
  $base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"

  $inline_sass = Hash.new
  $inline_coffeescript = Hash.new
 
  ext = File.extname( page_name )
  if ext.nil? == false && ext.length > 0
    page_name_parts = page_name.split(".")
    page_name = page_name_parts[0]
    
    result = case page_name_parts[1]
      when 'yaml'
        return renderYAML( page_name )
      when 'haml'
        return renderHAML( page_name )
      when 'html'
        return renderHTML( page_name )        
    end

  else
    rendered_page = renderYAML( page_name )
    
    # rough test of inline sass rendering
    raw_sass_string = $inline_sass.values.join('')
    compiled_sass_string = sass(raw_sass_string)
    
    #rough test of inline coffeescript rendering
    raw_coffee_string = $inline_coffeescript.values.join('')
    compiled_coffee_string = CoffeeScript.compile( raw_coffee_string )
    
    rendered_page << "<style>#{compiled_sass_string}</style>"
    rendered_page << "<script>#{compiled_coffee_string}</script>"
    
    return rendered_page
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
# Over riding the Coffeescript filter
# ---------------------------------
module Haml::Filters::Coffeescript
  include Haml::Filters::Base
  def render_with_options(text, options)
    fname = File.basename(options[:filename]).to_sym
    unless $inline_coffeescript.has_key?( fname )
      $inline_coffeescript[fname] = text;
    end  
    nil
  end
end

# ---------------------------------
# Over riding the Sass filter
# ---------------------------------
module Haml::Filters::Sass
  def render_with_options(text, options)
    fname = File.basename(options[:filename]).to_sym
    unless $inline_sass.has_key?( fname )
      $inline_sass[fname] = text;
    end
    nil
  end
end

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
