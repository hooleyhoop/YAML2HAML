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
  def render( cntx )
    rendered_output = ''
    if( @engine.nil? )
      #rendered_output << "no engine :("
      @subrenderers.each do |value|
        rendered_output << value.render( cntx )
      end      
    elsif
      #rendered_output << "yay engine!"
      rendered_template = @engine.render( cntx, { :_ =>self } )
      rendered_output << rendered_template 
    end
    return rendered_output    
  end

  #
  def insert( index, locals={} )
    #subrenderer = @subrenderers[index]
    #unless subrenderer.nil?
    #  subrenderer.render( locals )
    #end
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