require 'sinatra'
require 'coffee-script'
# sinatra-url-for # check this out for better urls
require_relative 'hoo_renderer'

class HooUtil

  #
  def HooUtil.cssHelper( filename )
    "css/#{filename}.css"
  end

  #
  def HooUtil.javascriptHelper( filename )
    "javascript/#{filename}.js"
  end
  
  # Compile a coffeescript to disk
  #
  def HooUtil.coffeescriptHelper( filename )
    src_file = "public/coffeescript/#{filename}.coffee"
    isFile = File.file?( src_file )   
    raise "cant find #{src_file} coffeescript" if !isFile
    raw_script = File.new( src_file, "r" )
    compiled_script = CoffeeScript.compile( raw_script )
    dst_file_path = "javascript/#{filename}.js"
    absolute_dst_file_path = File.join( 'public', dst_file_path )
    dst_file = File.new( absolute_dst_file_path, "w")
    dst_file.write( compiled_script )
    dst_file.close
    return dst_file_path
  end
  
  #
  def HooUtil.imageHelper( filename )
    "images/#{filename}"
  end

  #
  def HooUtil.loadYAML( yaml_template_name, page_directory )
    template_path = File.join( page_directory, "#{yaml_template_name}.yaml" )
    isFile = File.file?( template_path )   
    raise "cant find engine #{yaml_template_name} YAML" if !isFile
    test_yaml_hash = Psych.load_file( template_path )  
  end

  # badly recursively get unique keys
  def HooUtil.uniqueKeys( in_yaml_hash, result_set )
    in_yaml_hash.each do |key, value|
      result_set << key.to_s
      if value.instance_of? Hash
        uniqueKeys( value, result_set )
      end
    end
    result_set
  end

  # badly filter keys
  def HooUtil.keysStartingWith( in_set, firstChar )
    filtered_keys = Set.new  
    in_set.each do |value|
      if value[0] == firstChar
        filtered_keys << value
      end      
    end
    filtered_keys
  end

  # start building the view hierarchy
  def HooUtil.buildViewHierarchy( in_yaml_hash, engine_hash )
    root_view = HooRenderer.new
    buildViewHierarchyForParent( in_yaml_hash, root_view, engine_hash )
    root_view
  end

  # recursively build the view hierarchy
  def HooUtil.buildViewHierarchyForParent( in_yaml_hash, parent_renderer, engine_hash )
    in_yaml_hash.each do |key, value|
        engine_for_child = engine_hash[key]
        #raise "cant find engine #{key} in #{engine_hash}" if engine_for_child.nil?
        
        # set a child template
        unless engine_for_child.nil?
          child_view = HooRenderer.new( engine_for_child )
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

  # most simple case for now
  def HooUtil.buildTemplatePathsForKeys( template_directory, unique_keys )
    #  if key[0] == '.'
    #    template_name = key[1..-1]
    template_paths_h = Hash.new
    unique_keys.each do |value|
      template_path = File.join( template_directory, "#{value}.haml" )
      template_paths_h[value.to_sym] = template_path
    end
    return template_paths_h
  end

  #
  def HooUtil.buildTemplateEngines( paths_hash )
    template_engines = Hash.new
    paths_hash.each do |key, value|    
      template_as_string = IO.read( value )
      engine = Haml::Engine.new( template_as_string, { format: :html5, ugly: true } )
      template_engines[key] = engine
    end
    return template_engines
  end
  
  # Example
  def HooUtil.symbolize_keys(hash)
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

end