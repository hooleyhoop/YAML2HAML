require_relative 'hoo_renderer'

class HooUtil

  # badly recursively get unique keys
  def HooUtil.uniqueKeys( in_yaml_hash, result_set )
    in_yaml_hash.each do |key, value|
      result_set << key.to_s
      if value.instance_of? Hash
        uniqueKeys( value, result_set )
      end
    end
  end

  # badly filter keys
  def HooUtil.keysStartingWith( in_set, firstChar, out_set )
      in_set.each do |value|
        if value[0] == firstChar
          out_set.add value
        end      
      end  
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
        raise "cant find engine #{key} in #{engine_hash}" if engine_for_child.nil? 
        child_view = HooRenderer.new( engine_for_child )
        if value.instance_of? Hash
          buildViewHierarchyForParent( value, child_view, engine_hash )
        end
        parent_renderer.addSubRenderer(child_view)
    end
  end

  # most simple case for now
  def HooUtil.buildTemplatePathsForKeys( template_directory, unique_keys )
    #  if key[0] == '.'
    #    template_name = key[1..-1]
    template_paths = Hash.new
    unique_keys.each do |value|
      template_path = File.join( template_directory, "#{value.to_s}.haml" )
      template_paths[value.to_sym] = template_path
    end
    return template_paths
  end

  #
  def HooUtil.buildTemplateEngines( paths_hash )
    template_engines = Hash.new
    paths_hash.each do |key, value|    
      template_as_string = IO.read( value )
      engine = Haml::Engine.new( template_as_string )
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