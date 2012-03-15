"use strict"

# helper
namespace = ((target, name, block) ->
  [target, name, block] = [(if typeof exports isnt 'undefined' then exports else window), arguments...] if arguments.length < 3
  top    = target
  target = target[item] or= {} for item in name.split '.'
  block target, top
)

# Our top level namespace
namespace 'ABoo', ((exports) ->
  # `exports` is where you attach namespace members
  exports.main = -> 
    console.log "starting up.."
)

moduleKeywords = ['extended', 'included']

class ABoo.Module
  @extend: (obj) ->
    for key, value of obj when key not in moduleKeywords
      @[key] = value

    obj.extended?.apply(@)
    this

  @include: (obj) ->
    for key, value of obj when key not in moduleKeywords
      # Assign properties to the prototype
      @::[key] = value

    obj.included?.apply(@)
    this

  # mass assign the parameters
  constructor: ( opts={} )->
    for k,v of opts
      `if( k in this ) {
        this[k]=v;
      } else {
        console.error( "wtf? " + k);
      }`
    