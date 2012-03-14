require 'sinatra/base'
require 'erb'

module Sinatra
  module HooHelp

  #
  def yamlTemplatePathForName( yaml_template_name, page_directory )

    found_files = Dir.glob("#{page_directory}/**/#{yaml_template_name}.yaml*")
    raise "can't find yaml '#{yaml_template_name}'" if found_files.length == 0
    warn("more than one '#{yaml_template_name}' template found") if found_files.length > 1

    template_path = found_files[0]
    isFile = File.file?( template_path )   
    raise "cant find engine #{yaml_template_name} YAML" if !isFile
    return template_path
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
    #  if key[0] == '_'
    #    template_name = key[1..-1]
    
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


  end
  helpers HooHelp
end