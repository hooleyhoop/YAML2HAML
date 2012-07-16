require 'bundler/setup'
Bundler.require(:default)
#require 'sinatra'
#require 'yaml'
require 'pp'
require 'nokogiri'
require "sinatra/reloader" if development?

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

  set :css_directory, File.join( settings.views_directory, 'css' )
  set :scss_directory, File.join( settings.views_directory, 'scss' )  
  set :javascript_directory, File.join( settings.views_directory, 'javascript' )
  set :coffeescript_directory, File.join( settings.views_directory, 'coffeescript' )

  set :images_directory, File.join( settings.public_folder, 'images' )
end

#
def renderYAML( page_name )

  yaml_hash_or_array = loadYAMLNamed( page_name, settings.page_directory )
  #puts  yaml_hash_or_array.inspect
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

def cssDependenciesIncludeString
  css_includes = ""
  # pp "count is #{$css_deps.length}" 
  $css_deps.each { |x|
    # pp "dep is #{x}" 
    css_file = cssHelper(x)
    css_includes += "<link rel='stylesheet' type='text/css' href='#{css_file}' />"
  }
  return css_includes
end
def sassDependenciesIncludeString
  sass_includes = ""
  $sass_deps.each { |x|
    sass_file = scssHelper(x)
    sass_includes += "<link rel='stylesheet' type='text/css' href='#{sass_file}' />"    
  }
  return sass_includes
end

# A single haml file is output
def render_single_haml( page_name, properties={} )
  rendered_haml = renderHAML(page_name, properties)
  # inject the css
  # pp "Render haml #{page_name}"
  # pp caller[0][/`.*'/][1..-2]
  css_includes = cssDependenciesIncludeString()
  sass_includes = sassDependenciesIncludeString()
  return "<html>
  <head>
  #{css_includes}
  #{sass_includes}
  </head>
  <body>
  #{rendered_haml}
  </body>
  </html>"  
end

def renderHAML( page_name, properties={} )
  found_file = assertSingleFile( Dir.glob("#{settings.template_directory}/**/#{page_name}.haml"), page_name )
  rendered_haml = haml(File.read(found_file), locals: properties )
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
  $css_deps = Array.new
  $sass_deps = Array.new

  ext = File.extname( page_name )
  if ext.nil? == false && ext.length > 0
    page_name_parts = page_name.split(".")
    page_name = page_name_parts[0]
    
    result = case page_name_parts[1]
      when 'yaml'
        return renderYAML( page_name )
      when 'haml'
        return render_single_haml( page_name )
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
    
    # inject the css dependencies 
    # Nokogiri test
    doc = Nokogiri::HTML(rendered_page)
    head = doc.at('//head')
    if head.nil?
        rendered_page = "<html><head></head><body>#{rendered_page}</body></html>"
        doc = Nokogiri::HTML(rendered_page)
        head = doc.at('//head')
    end
    pp "Render page"
    head << cssDependenciesIncludeString()
    head << "<style>#{compiled_sass_string}</style>"
    head << "<script>#{compiled_coffee_string}</script>"
    
    return doc.to_s
  end
  return "failed to handle #{page_name}#{ext}"
end

# ROUTES

# /public are served automatically?
#get "/css/type.css" do
#  content_type 'text/css'
#  send_file File.expand_path('index.html', settings.public)
#end

# render css
get '/assets/css/:asset_name.css' do
  css_name = params[:asset_name]
  pp "looking for css.. #{css_name}"
  found_file = assertSingleFile( Dir.glob("#{settings.css_directory}/**/#{css_name}.css"), css_name )
  return send_file found_file
end

# render javascript
get '/assets/javascript/:asset_name.javascript' do
  js_name = params[:asset_name]
  found_file = assertSingleFile( Dir.glob("#{settings.javascript_directory}/**/#{js_name}.js"), js_name )
  return send_file found_file
end

# render named template
get '/:page_name.?/?' do
  renderPage( params[:page_name] )
end

# render index
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

# ------------------------------
# New css_deps filter, use :cssdeps
# ------------------------------
module Haml::Filters::Cssdeps
  include Haml::Filters::Base
  def render(text)
    text.split(/\r?\n|\r/).each { |line|
      clean_line = line.strip
      if clean_line.length >0
        # pp "found.. #{clean_line}" 
        # keep a reference to css dependencies in global $css_deps
        $css_deps << clean_line  unless $css_deps.include? clean_line
      end
    }
    nil
  end
end
module Haml::Filters::Sassdeps
  include Haml::Filters::Base
  def render(text)
    text.split(/\r?\n|\r/).each { |line|
      clean_line = line.strip
      if clean_line.length >0
        # pp "found.. #{clean_line}" 
        # keep a reference to css dependencies in global $sass_deps
        $sass_deps << clean_line  unless $sass_deps.include? clean_line
      end
    }
    nil
  end
end


#puts YAML::dump(engine_hash)
# use pretty print instead!