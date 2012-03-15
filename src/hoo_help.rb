require 'sinatra/base'
require 'erb'
require 'coffee-script'
require 'sass'
require 'pathname'

module Sinatra
  module HooHelp

  # --------------------------------------------------------------------------------------
  # TEMPLATE PARSING
  # --------------------------------------------------------------------------------------
  
  #
  def yamlTemplatePathForName( yaml_template_name, page_directory )

    found_file = assertSingleFile( Dir.glob("#{page_directory}/**/#{yaml_template_name}.yaml*"), yaml_template_name )
    return found_file
  end

  # .yaml or .yaml.erb
  def yamlFileToHash( template_file_path )

    # Experimental parse .erb YAML
    yaml_file_string = File.read( template_file_path )

    test_yaml_hash = nil    
    ext = File.extname( template_file_path )
    result = case ext
      when ".yaml"
        # parse a YAML file
        test_yaml_hash = Psych.load( yaml_file_string )
        
      when ".erb"
        # parse erb > yaml
        erb_src = ERB.new( yaml_file_string )
        # everu Object has a binding method?? allowing another object to access methods
        erb_locals = binding()
        yaml_file_string = erb_src.result(erb_locals)
        test_yaml_hash = Psych.load( yaml_file_string )        
      
      else
        puts "What?? #{ext}"
    end
    return test_yaml_hash
  end
  
  # load a template expanding referenced sub templates
  #
  def loadYAMLNamed( yaml_template_name, page_directory )
    
    template_path = yamlTemplatePathForName( yaml_template_name, page_directory )
    yaml_hash = yamlFileToHash( template_path )
    
    # recursively replace yaml objects
    yaml_hash = recursivelyReplaceYaml(yaml_hash)
    return yaml_hash
  end

  # replace all occurrences of 'yaml' with the contents of that template
  def recursivelyReplaceYaml(hash)
    hash.inject({}){|result, (key, value)|
            
      if key == 'yaml'
        # load the sub-template and move all key values to this hash
        new_hash = loadYAMLNamed( value, settings.page_directory )
        new_hash.each_pair do |k,v|
          result[k] = v      
        end
      else
        if value.is_a?(Hash)
          new_value = recursivelyReplaceYaml(value)
          result[key] = new_value      
        else
          result[key] = value      
        end
      end
      result
  }
  end
  
  # Example
  def symbolize_keys(hash)
    hash.inject({}){|result, (key, value)|
      new_key = case key
        when String then key.to_sym
        else key
      end
      new_value = case value
        when Hash then symbolize_keys(value)
        else value
      end
      result[new_key] = new_value
      result
  }
  end

  # badly recursively get unique keys as symbols
  def uniqueKeys( in_yaml_hash, result_set )
    in_yaml_hash.each do |key, value|
      result_set << key
      if value.instance_of? Hash
        uniqueKeys( value, result_set )
      end
    end
    result_set
  end

  # badly filter keys
  def keysStartingWith( in_set, firstChar )
    filtered_keys = Set.new  
    in_set.each do |value|
      if value[0] == firstChar
        filtered_keys << value
      end      
    end
    filtered_keys
  end

  # template names must be unique but can be in sub-directories
  #
  def buildTemplatePathsForKeys( template_directory, unique_keys )
    
    # recursively go thru the dir comparing each file against needed keys until all are found
    template_paths_h = Hash.new    
    keys_to_find = Set.new(unique_keys)
    Dir.glob("#{template_directory}/**/*.haml").each do|f|
      name = File.basename(f,'.*').to_sym
      if keys_to_find.include?(name)
        template_paths_h[name] = f
        keys_to_find.delete(name)
        if keys_to_find.length == 0
          break
        end
      end
    end

    return template_paths_h
  end

  #
  #
  def buildTemplateEngines( paths_hash )
    template_engines = Hash.new
    paths_hash.each do |key, path_value|    
      template_as_string = IO.read( path_value )
      engine = Haml::Engine.new( template_as_string, { format: :html5, ugly: true, filename: path_value } )
      template_engines[key] = engine
    end
    return template_engines
  end

  # start building the view hierarchy
  def buildViewHierarchy( in_yaml_hash, engine_hash )
    root_view = HooRenderer.new( 'root' )
    buildViewHierarchyForParent( in_yaml_hash, root_view, engine_hash )
    root_view
  end

  # recursively build the view hierarchy
  def buildViewHierarchyForParent( in_yaml_hash, parent_renderer, engine_hash )
    in_yaml_hash.each do |key, value|
        engine_for_child = engine_hash[key]
        #raise "cant find engine #{key} in #{engine_hash}" if engine_for_child.nil?
        
        # set a child template
        unless engine_for_child.nil?
          child_view = HooRenderer.new( key, engine_for_child )
          if value.instance_of? Hash
            buildViewHierarchyForParent( value, child_view, engine_hash )
          end
          parent_renderer.addSubRenderer(child_view)
        else
          # set a custom property
          parent_renderer.setCustomProperty( key, value ) 
        end
    end
  end
  
  def assertSingleFile( found_files, filename )
    raise "can't find file '#{filename}'" if found_files.length == 0
    warn("more than one '#{filename}' found") if found_files.length > 1
    absolute_path = found_files[0]
    isFile = File.file?( absolute_path )   
    raise "cant find file #{filename}" if !isFile
    return absolute_path
  end
  
  # --------------------------------------------------------------------------------------
  # VIEW HELPERS
  # --------------------------------------------------------------------------------------
  
  #
  def cssHelper( filename )

    found_file = assertSingleFile( Dir.glob("#{settings.css_directory}/**/#{filename}.css"), filename )
    
    # real = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test/public/css/third_party/base.css
    # needed = http://0.0.0.0:4567/css/third_party/base.css
    
    # root = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test
    # base = http://0.0.0.0:4567
    # absolute_css_dir = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test/views/scss
    # relative_css_dir = /css
    
    relative_path = Pathname.new( found_file ).relative_path_from( Pathname.new( settings.css_directory ) ).to_s
    # third_party/base.css

    css_file_path = File.join( $base_url, 'css',  relative_path )
    return css_file_path
  end
  
  #
  def javascriptHelper( filename )
  
    found_file = assertSingleFile( Dir.glob("#{settings.javascript_directory}/**/#{filename}.js"), filename )
    relative_path = Pathname.new( found_file ).relative_path_from( Pathname.new( settings.javascript_directory ) ).to_s
    js_file_path = File.join( $base_url, 'javascript',  relative_path )
    return js_file_path
  end


  #
  def scssHelper( filename )
  
    # root = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test
    # base = http://0.0.0.0:4567
    # scss_dir = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test/views/scss
    # required = http://0.0.0.0:4567scss/#{filename}.css
    
    src_file = assertSingleFile( Dir.glob("#{settings.scss_directory}/**/#{filename}.scss"), filename )

    sass_cache = File.join( settings.root, '/caches-hoo/sass' )
    partials_paths = [ File.join( settings.scss_directory, 'partials' ) ]
    compiled_style_sheet = Sass::Engine.for_file( src_file, { syntax: :scss, load_paths: partials_paths, cache: true , cache_location: sass_cache } ).render

    # create and save the css
    absolute_dst_file_path = File.join( settings.css_directory, "generated/#{filename}.css" )
    dst_file = File.new( absolute_dst_file_path, "w" )
    dst_file.write( compiled_style_sheet )
    dst_file.close()
    
    return cssHelper( filename )
  end
      
      
  # Compile a coffeescript to disk
  #
  def coffeescriptHelper( filename )
  
    src_file = assertSingleFile( Dir.glob("#{settings.coffeescript_directory}/**/#{filename}.coffee"), filename )
    raw_script = File.new( src_file, "r" )
    compiled_script = CoffeeScript.compile( raw_script )
    raw_script.close

    dst_file_path = File.join( settings.javascript_directory, "generated/#{filename}.js" )
    dst_file = File.new( dst_file_path, "w")
    dst_file.write( compiled_script )
    dst_file.close
    
    return javascriptHelper( filename )
  end      
      
  end
  helpers HooHelp
end