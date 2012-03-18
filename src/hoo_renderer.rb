require 'haml'

class HooRenderer

  attr_accessor :engine
  attr_accessor :subrenderers
  attr_accessor :parentRenderer
  attr_accessor :properties
  
  #
  def initialize( template_name, engine=nil )
    @template_name = template_name
    @engine = engine
    @subrenderers=[]
    @properties={}
    @current_cntx = nil
  end
  
  #
  def addSubRenderer( child )
    self.subrenderers << child
    if( child.parentRenderer!=nil )
      raise "View allready has parentView"
    end
    child.parentRenderer = self
    child.wasAddedToParentRenderer()  
  end

  # nested views can be added in one go.  eg:
  #   view.add_subviews(page => [
  #     header,
  #     {content=>[left, right]},
  #     footer
  #   ])
  def add_subrenderers( *views )
    views.each do |sub|
      case sub
      when Hash
        sub.each{|child, grandchildren|
          child.add_subrenderers(grandchildren)
          addSubRenderer(child)
        }
      when Array
        add_subrenderers(*sub)
      else
        addSubRenderer(sub)
      end
    end
  end

  #
  def wasAddedToParentRenderer
  end
    
  #
  def render_the_engine( cntx, additional_locals=nil )

    @current_cntx = cntx
    rendered_output = ''
    if( @engine.nil? )
      #rendered_output << "no engine :("
      @subrenderers.each_with_index do |value, i|
        puts "rendering #{i}"      
        rendered_output << value.render_the_engine( @current_cntx )
      end      
    elsif
      haml_locals = { :_ =>self }
      haml_locals.merge!(additional_locals) unless additional_locals.nil? 
      rendered_template = @engine.render( @current_cntx, haml_locals )
      rendered_output << rendered_template 
    end
    @current_cntx = nil
    return rendered_output    
  end

  #
  def insert( index, overidden_locals=nil )
    subrenderer = @subrenderers[index]
    unless subrenderer.nil?
      if( @current_cntx.nil? )
        raise "No renderering context!" 
      end
      return subrenderer.render_the_engine( @current_cntx, overidden_locals )
    end
  end

  #
  def prop( prop_name, default_value=nil )
    custom_prop = @properties[prop_name.to_sym]
    return custom_prop || default_value
  end
  alias :[] :prop

  #
  def setCustomProperty( prop_name, default_value )
    @properties[prop_name.to_sym] = default_value
  end

  #
  def subrenderers
    @subrenderers ||= []
  end

  #
  def subrenderers=( new_subrenderers )
    @subrenderers=[]
    add_subrenderers( new_subrenderers )
  end

  # 2168956940
  def id
    self.object_id
  end
  
  def haml_object_ref
    if @template_name[0] == '_'
      return @template_name[1..-1]
    end
    @template_name
  end  
end