# Stanbool Enhancement API

Stanbol = Stanbol ? {}
# filter for TextAnnotations
Stanbol.getTextAnnotations = (enhList) ->
    res = _(enhList)
    .filter (e) ->
        e.isof "<#{ns.enhancer}TextAnnotation>"
    res = _(res).sortBy (e) ->
        conf = Number e.get "enhancer:confidence" if e.get "enhancer:confidence"
        -1 * conf

    _(res).map (enh)->
        new Stanbol.TextEnhancement enh, enhList

# filter the entityManager for TextAnnotations
Stanbol.getEntityAnnotations = (enhList) ->
    _(enhList)
    .filter (e) ->
        e.isof "<#{ns.enhancer}EntityAnnotation>"

# Generic API for a TextEnhancement
# A TextEnhancement object has the methods for getting generic
# text-enhancement-specific properties.
class Stanbol.TextEnhancement
    constructor: (enhancement, enhList) ->
        @_enhancement = enhancement
        @_enhList = enhList
        @id = @_enhancement.getSubject()
    # the text the annotation is for
    getSelectedText: ->
        res = @_vals("enhancer:selected-text")
        if typeof res is "string"
            return res
        if typeof res is "object"
            return res.toString()
    # confidence value
    getConfidence: ->
        @_vals("enhancer:confidence")
    # get Entities suggested for the text enhancement (if any)
    getEntityEnhancements: ->
        rawList = @_enhancement.get("entityAnnotation")
        return [] unless rawList
        rawList = _.flatten [rawList]
        _(rawList).map (ee) =>
            new Stanbol.EntityEnhancement ee, @
    # The type of the entity suggested (e.g. person, location, organization)
    getType: ->
        @_uriTrim @_vals("dcterms:type")
    # Optional, not used
    getContext: ->
        @_vals("enhancer:selection-context")
    # start position in the original text
    getStart: ->
        Number @_vals("enhancer:start")
    # end position in the original text
    getEnd: ->
        Number @_vals("enhancer:end")
    # Optional
    getOrigText: ->
        ciUri = @_vals("enhancer:extracted-from")
        @_enhList[ciUri]["http://www.semanticdesktop.org/ontologies/2007/01/19/nie#plainTextContent"][0].value
    _vals: (key) ->
        @_enhancement.get key
    _uriTrim: (uriRef) ->
        return [] unless uriRef
        if uriRef instanceof Backbone.Model or uriRef instanceof Backbone.Collection
            bbColl = uriRef
            return (mod.get("@subject").replace(/^<|>$/g, "") for mod in bbColl.models)
        else
        _(_.flatten([uriRef])).map (ur) ->
            ur.replace /^<|>$/g, ""

# Generic API for an EntityEnhancement. This is the implementation for Stanbol
class Stanbol.EntityEnhancement
    constructor: (ee, textEnh) ->
        @_enhancement = ee
        @_textEnhancement = textEnh
        @
    getLabel: ->
        @_vals("enhancer:entity-label")
        .toString()
        # for compatibility with stanbol before 0.9
        .replace(/(^\"*|\"*@..$)/g,"")
    getUri: ->
        @_uriTrim(@_vals("enhancer:entity-reference"))[0]
    getTextEnhancement: ->
        @_textEnhancement
    getTypes: ->
        @_uriTrim @_vals("enhancer:entity-type")
    getConfidence: ->
        Number @_vals("enhancer:confidence")
    _vals: (key) ->
        res = @_enhancement.get key
        return [] unless res
        if res.pluck
            res.pluck("@subject")
        else res
    _uriTrim: (uriRef) ->
        return [] unless uriRef
        if uriRef instanceof Backbone.Collection
            bbColl = uriRef
            return (mod.getSubject().replace(/^<|>$/g, "") for mod in bbColl.models)
        else if uriRef instanceof Backbone.Model
            uriRef = uriRef.getSubject()

        _(_.flatten([uriRef])).map (ur) ->
            ur.replace /^<|>$/g, ""

