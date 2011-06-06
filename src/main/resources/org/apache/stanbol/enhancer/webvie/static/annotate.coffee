# annotate.js

((jQuery) ->
    # define namespaces
    ns =
        rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
        enhancer: 'http://fise.iks-project.eu/ontology/'
        dc: 'http://purl.org/dc/terms/'

    # filter the entityManager for TextAnnotations    
    getTextAnnotations = () ->
        VIE.EntityManager.entities.filter (e) ->
            e.attributes["<#{ns.rdf}type>"].indexOf("#{ns.enhancer}TextAnnotation") != -1
    
    # A suggestion object has the methods for getting generic enhancement-specific 
    # properties
    Suggestion = (enhancement) -> 
        @_enhancement = enhancement
        id = @_enhancement.id
    Suggestion.prototype = 
        getSelectedText: -> 
            @_enhancement
            .toJSON()["<#{ns.enhancer}selected-text>"]
        getEntityEnhancements: ->
            entityUris = @_enhancement
                .toJSON()["<#{ns.dc}relation>"]
            _([entityUris]).flatten().map (uri) ->
                VIE.EntityManager.getBySubject uri
        getType: ->
            @_enhancement
                .toJSON()["<#{ns.dc}type>"]

    # get create a dom element containing only the occurrence of the found entity
    # (getOrCreateDomElement is to be implemented)
    getOrCreateDomElement = (element, text, options) ->
        if options is undefined
            options = {}
        domEl = element
        # find the text node
        if(element.textContent.indexOf(text) is -1)
            throw "'#{text}' doesn't appear in the text block."
            return $()
        while domEl.textContent.indexOf(text) isnt -1 && domEl.nodeName isnt '#text'
            domEl = _(domEl.childNodes).detect (el) ->
                el.textContent.indexOf(text) isnt -1
        if(options.createMode is "existing" && domEl.parentElement.textContent is text)
            return domEl.parentElement
        else
            pos = domEl.nodeValue.indexOf text
            len = text.length
            domEl.splitText pos + len
            newElement = document.createElement options.createElement or 'span'
            newElement.innerHTML = text
            domEl.parentElement.replaceChild newElement, domEl.splitText pos
            return $ newElement
    
    processSuggestion = (suggestion, parentEl) ->
        el = getOrCreateDomElement parentEl[0], suggestion.getSelectedText()
        console.info el
        
        
    
    jQuery.fn.analyze = () ->
        analyzedNode = @
        VIE2.connectors['stanbol'].analyze @,
            success: (rdf) ->
                # Get enhancements
                rdfJson = rdf.where("?s <#{ns.rdf}type> <#{ns.enhancer}Enhancement>")
                    .where('?s ?p ?o')
                    .dump()
                
                console.info rdfJson 
                VIE.EntityManager.getByRDFJSON rdfJson
                console.info "VIE.EntityManager", VIE.EntityManager
                textAnnotations = getTextAnnotations()
                jQuery.each textAnnotations, ->
                    s = new Suggestion @
                    console.info s._enhancement, 
                        'selectedText', s.getSelectedText(), 
                        'type', s.getType(),
                        'EntityEnhancements', s.getEntityEnhancements()
                    processSuggestion s, analyzedNode
)(jQuery)
