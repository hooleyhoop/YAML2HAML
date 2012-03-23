require 'sinatra/base'
require 'erb'
require 'coffee-script'
require 'sass'
require 'pathname'

module Sinatra
  module HooHelp

  def installRenderEngines( renderer_hierachy, engine_hash )
    renderer_hierachy.indexed_subrenderers.each do |renderer|
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
    root_renderer.indexed_subrenderers.each do |renderer|
      result_set << renderer.template_name
      uniqueTemplateKeys( renderer, result_set )
    end
  end

  #
  def buildViewContentsFromHash( parent_renderer, content_hash )
    raise "!!! parent_renderer is nil" if parent_renderer.nil?
    raise "!!! content_hash is nil" if content_hash.nil?

    content_hash.each_pair do |key,value|
      #-- modify key
      # hack to allow multiple same template keys in one hash - we dont use the index     
      key_parts = key.split("#")
      key_first = key_parts.first
      key_index = key_parts[1]
      if key_first[0] == '_'
        child_renderer = HooRenderer.new( key_first.to_sym )
        addSubRendererToParent( parent_renderer, child_renderer, key_index, value )

      elsif key_first=='yaml'
          buildViewContentsFromValue( parent_renderer, value )

      elsif key_first=='$yield' && !value.nil?
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
        key_parts = key.split("#")
        key_first = key_parts.first
        key_index = key_parts[1]
        
        child_renderer = HooRenderer.new( key_first.to_sym )        
        addSubRendererToParent( parent_renderer, child_renderer, key_index, nil )

      else
        buildViewContentsFromValue( parent_renderer, value )
      end    
    end
  end

  #
  def addSubRendererToParent( parent, child, key_index, value )

    # not sure if really a string..
    unless key_index.nil?        
      child.setCustomProperty( '_index_string', key_index )
    end
    unless value.nil?
      buildViewContentsFromValue( child, value )
    end
    parent.addSubRenderer( child, key_index )
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

    raise "nil args" if (yaml_template_name.nil? || page_directory.nil? )

    found_file = assertSingleFile( Dir.glob("#{page_directory}/**/#{yaml_template_name}.yaml*"), yaml_template_name )
    return found_file
  end

  # .yaml or .yaml.erb
  def yamlFileToHashOrArray( template_file_path )

    raise "nil args" if template_file_path.nil? 

    # Experimental parse .erb YAML
    yaml_file_string = File.read( template_file_path )

    test_yaml_hash = nil    
    ext = File.extname( template_file_path )
    result = case ext
      when '.yaml'
        # parse a YAML file
        test_yaml_hash = YAML.load( yaml_file_string )
        
      when '.erb'
        # parse erb > yaml
        erb_src = ERB.new( yaml_file_string )
        # every Object has a binding method?? allowing another object to access methods
        erb_locals = binding()
        yaml_file_string = erb_src.result(erb_locals)
        test_yaml_hash = YAML.load( yaml_file_string )        
      
      else
        puts "What?? #{ext}"
    end
    return test_yaml_hash
  end
  
  # load a template expanding referenced sub templates
  #
  def loadYAMLNamed( yaml_template_name, page_directory )

    raise "nil args" if (yaml_template_name.nil? || page_directory.nil? )

    template_path = yamlTemplatePathForName( yaml_template_name, page_directory )
    yaml_hash_or_array = yamlFileToHashOrArray( template_path )

    # recursively replace yaml objects
    yaml_hash_or_array = recursivelyLoadYaml( yaml_hash_or_array )

    return yaml_hash_or_array
  end


#
def firstHashThatContainsKeyFromHashOrArray( hash_or_array, key ) 
  x = case hash_or_array
    when Hash
      firstHashThatContainsKeyFromHash( hash_or_array, key )
    when Array
      firstHashThatContainsKeyFromArray( hash_or_array, key )
    else
      nil
  end
  return x
end

#
def firstHashThatContainsKeyFromArray( array, key )
  x = array.each do |v|
    found = firstHashThatContainsKeyFromHashOrArray( v, key )
    break found if found.nil? == false
  end
  return x
end

#
def firstHashThatContainsKeyFromHash( a_hash, key )

  if a_hash.has_key?( key )
    return a_hash
  else
    a_hash.each_pair do |k,v|
      found = firstHashThatContainsKeyFromHashOrArray( v, key )
      unless found.nil?
        return found
      end
    end
  end
  return nil
end

#
def replaceValueKeyWithContents( hash_or_array, replace_key, new_contents )

  raise "nil args" if (hash_or_array.nil? || replace_key.nil? || new_contents.nil?)
  case hash_or_array
    when Hash || Array
    else
      raise "wtf? #{hash_or_array}"
  end  
  
  if hash_or_array.is_a? Array
    return hash_or_array.each{|v| replaceValueKeyWithContents(v, replace_key, new_contents)}
  end
  
  hash_or_array.each do |key, value|
    if key == replace_key
      hash_or_array[key] = new_contents
    else
      case value
        when Hash || Array
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
  
    raise "nil args" if a_hash.nil?
  
    new_hash = Hash.new
    a_hash.each_pair do |key,value|
      # load linked yaml
      if key.split('#').first == 'yaml'
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

    raise "nil args" if tagContents.nil?
  
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

    raise "nil args" if hash_of_properties.nil?

    template_name = hash_of_properties['name']
    
    # hash_of_properties has the name of one template
    if template_name.nil? == false
      hash_of_properties.delete('name')  
      # load the sub-template and move all key values to this a_hash
      new_hash_or_array = loadYAMLNamed( template_name, settings.page_directory )

      unless hash_of_properties.empty?
       overideTemplateProperties( new_hash_or_array, hash_of_properties )
      end
    
      return new_hash_or_array
      
    # hash_of_properties has a list of haml tags 
    else
      new_hash_or_array = recursivelyReplaceYAMLTagsInHash( hash_of_properties )
      return new_hash_or_array
    end
  end
  
  #
  def overideTemplateProperties( hash_or_array, new_contents )
  
    raise "nil args" if ( hash_or_array.nil? || new_contents.nil? )
  
    new_contents.each_pair do |key, value|
    
      # replace yield#? in linked haml
      if key.match(/^content_for/)
        index = key.split("#")[1]
        sub_template_hash_or_array = loadContentsOfYAMLTag( value )
        key_to_replace = "$yield##{index}"

        replaceValueKeyWithContents( hash_or_array, key_to_replace, sub_template_hash_or_array )
                
      else
      
        # crappy kvc type approach
        array_of_key_paths = key.split('.')
        key_value = array_of_key_paths.pop
        target = hash_or_array
        
        array_of_key_paths.each do |key_path_part|
          target = firstHashThatContainsKeyFromHashOrArray( target, key_path_part )
        end
     
        replaceValueKeyWithContents( target, key_value, value )
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
      engine = Haml::Engine.new( template_as_string, { format: :html5, ugly: false, filename: path_value } )
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
  
  def absolutePathFromPublicFolder( file_path )
    relative_path = Pathname.new( file_path ).relative_path_from( Pathname.new( settings.public_folder ) ).to_s
    absolute_file_path = File.join( '/',  relative_path )
  end

  #
  def cssHelper( filename )
    found_file = assertSingleFile( Dir.glob("#{settings.css_directory}/**/#{filename}.css"), filename )
    absolutePathFromPublicFolder( found_file )
  end
  
  #
  def javascriptHelper( filename )
    found_file = assertSingleFile( Dir.glob("#{settings.javascript_directory}/**/#{filename}.js"), filename )
    absolutePathFromPublicFolder( found_file )
  end

  #
  def imageHelper( filename )
    img_file = assertSingleFile( Dir.glob("#{settings.images_directory}/**/#{filename}"), filename )
    absolutePathFromPublicFolder( img_file )
  end     
     
  #
  def scssHelper( filename )
  
    # root = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test
    # base = http://0.0.0.0:4567
    # scss_dir = http://0.0.0.0:4567/Users/shooley/Dropbox/Programming/sinatra_test/views/scss
    # required = http://0.0.0.0:4567scss/#{filename}.css
    
    src_file = assertSingleFile( Dir.glob("#{settings.scss_directory}/**/#{filename}.{scss,sass}"), filename )
    ext = File.extname( src_file )[1..-1].to_sym

    sass_cache = File.join( settings.root, '/caches-hoo/sass' )
    partials_paths = [ File.join( settings.scss_directory, 'partials' ) ]
    compiled_style_sheet = Sass::Engine.for_file( src_file, { syntax: ext, load_paths: partials_paths, cache: true , cache_location: sass_cache } ).render

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
     
  def shaqAtaq
    "oh yeah"
  end
     
      
  end
  helpers HooHelp
end