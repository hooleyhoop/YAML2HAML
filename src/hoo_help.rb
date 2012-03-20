require 'sinatra/base'
require 'erb'
require 'coffee-script'
require 'sass'
require 'pathname'

module Sinatra
  module HooHelp

  def installRenderEngines( renderer_hierachy, engine_hash )
    renderer_hierachy.subrenderers.each do |renderer|
      cached_engine = engine_hash[renderer.template_name]
      raise "failed to fine engine #{renderer.template_name.to_s}" if cached_engine.nil?
      renderer.engine = cached_engine       
      installRenderEngines( renderer, engine_hash )
    end  
  end
  
  # --------------------------------------------------------------------------------------
  # HASH AND ARRAY HELPERS
  # --------------------------------------------------------------------------------------

  
  # badly recursively get unique keys as symbols
  def uniqueTemplateKeys( root_renderer, result_set )
    root_renderer.subrenderers.each do |renderer|
      result_set << renderer.template_name
      uniqueTemplateKeys( renderer, result_set )
    end
  end

  #
  def buildViewContentsFromHash( parent_renderer, content_hash )
    raise "!!! parent_renderer is nil" if parent_renderer.nil?
    raise "!!! content_hash is nil" if content_hash.nil?

    content_hash.each_pair do |key,value|
      if key[0] == '_'
        #-- modify key
        # hack to allow multiple same template keys in one hash - we dont use the index        
        key = key.split("#").first # remove #index
        child_view = HooRenderer.new( key.to_sym )
        unless value.nil?
          buildViewContentsFromValue( child_view, value )
        end
        parent_renderer.addSubRenderer( child_view )

      elsif key.split('#').first=='yaml'
          buildViewContentsFromValue( parent_renderer, value )

      elsif key.split('#').first=='$yield' && !value.nil?
        buildViewContentsFromValue( parent_renderer, value )
  
      else
          parent_renderer.setCustomProperty( key, value ) 
      end    
    end
  end
  
  #
  def buildViewContentsFromArray( parent_renderer, content_array )
    raise "!!! parent_renderer is nil" if parent_renderer.nil?
    raise "!!! content_array is nil" if content_array.nil?

    content_array.each do |value|
      if value[0] == '_'
        # hack to allow multiple same template keys in one hash - we dont use the index
        value = value.split("#").first # remove #index
        child_renderer = HooRenderer.new( value.to_sym )
        parent_renderer.addSubRenderer( child_renderer )  
      else
        buildViewContentsFromValue( parent_renderer, value )
      end    
    end
  end

  #
  def buildViewContentsFromValue( parent_renderer, content_array_or_hash_or_value )
    raise "!!! parent_renderer is nil" if parent_renderer.nil?
    raise "!!! content_array_or_hash_or_value is nil" if content_array_or_hash_or_value.nil?
    case content_array_or_hash_or_value
      when Hash then buildViewContentsFromHash( parent_renderer, content_array_or_hash_or_value )
      when Array then buildViewContentsFromArray( parent_renderer, content_array_or_hash_or_value )
      else parent_renderer.addSpecialAttribute( content_array_or_hash_or_value ) 
    end  
  end
  
  # root
  def buildRendererHierarchyFromYAML( yaml_hash_or_array )
    raise "!!! yaml_hash_or_array is nil" if yaml_hash_or_array.nil?  
    root_renderer = HooRenderer.new( :root )  
    buildViewContentsFromValue( root_renderer, yaml_hash_or_array )
    return root_renderer
  end
  
  
  
  # --------------------------------------------------------------------------------------
  # TEMPLATE PARSING
  # --------------------------------------------------------------------------------------
  
  #
  def yamlTemplatePathForName( yaml_template_name, page_directory )

    found_file = assertSingleFile( Dir.glob("#{page_directory}/**/#{yaml_template_name}.yaml*"), yaml_template_name )
    return found_file
  end

  # .yaml or .yaml.erb
  def yamlFileToHashOrArray( template_file_path )

    # Experimental parse .erb YAML
    yaml_file_string = File.read( template_file_path )

    test_yaml_hash = nil    
    ext = File.extname( template_file_path )
    result = case ext
      when '.yaml'
        # parse a YAML file
        test_yaml_hash = Psych.load( yaml_file_string )
        
      when '.erb'
        # parse erb > yaml
        erb_src = ERB.new( yaml_file_string )
        # every Object has a binding method?? allowing another object to access methods
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
    yaml_hash_or_array = yamlFileToHashOrArray( template_path )

    # recursively replace yaml objects
    yaml_hash_or_array = recursivelyLoadYaml( yaml_hash_or_array )

    return yaml_hash_or_array
  end

  
#
def replaceValueKeyWithContents( hash_or_array, replace_key, new_contents )
  if hash_or_array.is_a? Array
    return hash_or_array.each{|v| replaceValueKeyWithContents(v, replace_key, new_contents)}
  end
  
  hash_or_array.each_pair do |key, value|
    if key == replace_key
      hash_or_array[key] = new_contents
    else
      if value.is_a?(Hash) or value.is_a?(Array)
        replaceValueKeyWithContents(value, replace_key, new_contents)
      end
    end
  end
  hash_or_array
end
  
  # replace all occurrences of 'yaml' with the contents of that template by building a new hash / array
  # i don't think there is any need any more to duplicate the hash
  def recursivelyLoadYaml( hash_or_array )

    new_value = case hash_or_array
      when Hash 
        new_hash = recursivelyReplaceYAMLTagsInHash( hash_or_array )
        new_hash
        
      when Array 
        new_array = Array.new
        hash_or_array.each do |value|
          new_array << recursivelyLoadYaml( value )
        end
        new_array
      else 
        hash_or_array
    end      

    return new_value
  end

  #
  def recursivelyReplaceYAMLTagsInHash( a_hash )
    new_hash = Hash.new
    a_hash.each_pair do |key,value|
      # load linked yaml
      if key == 'yaml'
        new_hash_or_array_value = loadContentsOfYAMLTag(value)
        new_hash[key] = new_hash_or_array_value
      else
        new_hash[key] = recursivelyLoadYaml( value )
      end
    end
    return new_hash
  end
  
  #
  def loadContentsOfYAMLTag( tagContents )
    new_value = case tagContents
    when Hash
      loadYAMLFromHashOfTemplateNameAndProperties( tagContents )
    else
      loadYAMLNamed( tagContents, settings.page_directory )    
    end
    return new_value
  end
  
  #
  def loadYAMLFromHashOfTemplateNameAndProperties( hash_of_properties )

    template_name = hash_of_properties['name']
    hash_of_properties.delete('name')  
    
    # load the sub-template and move all key values to this a_hash
    new_hash_or_array = loadYAMLNamed( template_name, settings.page_directory )

    overideTemplateProperties( new_hash_or_array, hash_of_properties )
    
    return new_hash_or_array
  end
  
  #
  def overideTemplateProperties( hash_or_array, new_contents )
  
    new_contents.each_pair do |key, value|
      # replace yield#? in linked haml
      if key.match(/^content_for/)
        index = key.split("#")[1]
        sub_template_hash_or_array = loadContentsOfYAMLTag( value )
        key_to_replace = "$yield##{index}"
        replaceValueKeyWithContents( hash_or_array, key_to_replace, sub_template_hash_or_array )
                
      else
        replaceValueKeyWithContents( hash_or_array, key, value )
      end

    end  
  end
  
  # --------------------------------------------------------------------------------------
  # TEMPLATE HELPERS
  # --------------------------------------------------------------------------------------
  
  
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
    paths_hash.each_pair do |key, path_value|    
      template_as_string = IO.read( path_value )
      engine = Haml::Engine.new( template_as_string, { format: :html5, ugly: true, filename: path_value } )
      template_engines[key] = engine
    end
    return template_engines
  end

  #  
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
     
  #
  def imageHelper( filename )
    img_file = assertSingleFile( Dir.glob("#{settings.images_directory}/**/#{filename}"), filename )
    relative_path = Pathname.new( img_file ).relative_path_from( Pathname.new( settings.images_directory ) ).to_s
    img_file_path = File.join( $base_url, 'images',  relative_path )
    return img_file_path
  end     
     
     
      
  end
  helpers HooHelp
end