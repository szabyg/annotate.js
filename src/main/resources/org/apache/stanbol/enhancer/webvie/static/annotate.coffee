#     Annotate - a text enhancement interaction jQuery UI widget
#     (c) 2011 Szaby Gruenwald, IKS Consortium
#     Annotate may be freely distributed under the MIT license

((jQuery) ->
    # The annotate.js widget
    # 
    
    # define namespaces
    ns =
        rdf:      'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
        enhancer: 'http://fise.iks-project.eu/ontology/'
        dc:       'http://purl.org/dc/terms/'

    # filter the entityManager for TextAnnotations
    getTextAnnotations = () ->
        VIE.EntityManager.entities.filter (e) ->
            e.attributes["<#{ns.rdf}type>"].indexOf("#{ns.enhancer}TextAnnotation") != -1
    
    # filter the entityManager for TextAnnotations    
    getEntityAnnotations = () ->
        VIE.EntityManager.entities.filter (e) ->
            e.attributes["<#{ns.rdf}type>"].indexOf("#{ns.enhancer}EntityAnnotation") != -1
    
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
            _(getEntityAnnotations()).filter (ann) =>
                if _(ann.attributes["<#{ns.dc}relation>"]).flatten().indexOf(@_enhancement.id) isnt -1 then true
                else false
        getType: ->
            @_enhancement
                .toJSON()["<#{ns.dc}type>"]
        toJSON: ->
            @_enhancement.toJSON()

    # get create a dom element containing only the occurrence of the found entity
    # (getOrCreateDomElement is to be implemented)
    # TODO add the option 'context' for being able to find the 'right' occurrence
    getOrCreateDomElement = (element, text, options = {}) ->
        domEl = element
        # find the text node
        if(element.textContent.indexOf(text) is -1)
            throw "'#{text}' doesn't appear in the text block."
            return $()
        while domEl.textContent.indexOf(text) isnt -1 and domEl.nodeName isnt '#text'
            domEl = _(domEl.childNodes).detect (el) ->
                el.textContent.indexOf(text) isnt -1
        if options.createMode is "existing" and domEl.parentElement.textContent is text
            return domEl.parentElement
        else
            pos = domEl.nodeValue.indexOf text
            len = text.length
            domEl.splitText pos + len
            newElement = document.createElement options.createElement or 'span'
            newElement.innerHTML = text
            domEl.parentElement.replaceChild newElement, domEl.splitText pos
            return $ newElement
    
    # processSuggestion deals with one suggestion in an ancestor element of its occurrence
    processSuggestion = (suggestion, parentEl) ->
        el = $(getOrCreateDomElement parentEl[0], suggestion.getSelectedText(), createElement: 'span')
        sType = suggestion.getType()
        el.addClass('entity')
        .addClass(sType.substring(sType.lastIndexOf("/")+1))
        
        el.addClass "withSuggestions" if suggestion.getEntityEnhancements().length > 0
        w = el.annotationSelector suggestion: suggestion
        # console.info el, w.data('annotationSelector'), w.annotationSelector('option', 'suggestion').toJSON()
    
    # the analyze jQuery plugin runs a stanbol enhancement process
    jQuery.fn.analyze = () ->
        analyzedNode = @
        VIE2.connectors['stanbol'].analyze @,
            success: (rdf) ->
                # Get enhancements
                rdfJson = rdf.databank.dump()
                
                VIE.EntityManager.getByRDFJSON rdfJson
                textAnnotations = getTextAnnotations()
                jQuery.each textAnnotations, ->
                    s = new Suggestion @
                    console.info s._enhancement, 
                        'selectedText', s.getSelectedText(), 
                        'type', s.getType(),
                        'EntityEnhancements', s.getEntityEnhancements()
                    processSuggestion s, analyzedNode
    
    # the annotationSelector makes an annotated word interactive
    jQuery.widget 'IKS.annotationSelector',
        options:
            suggestion: null
        annotate: (entityEnhancement, styleClass) ->
            @element.attr 'about', entityEnhancement.get "<#{ns.enhancer}entity-reference>"
            @element.addClass styleClass
            # TODO write the fact it's acknowledged into the VIE
            console.info "created enhancement in", @element
        _renderMenu: (ul, entityEnhancements) ->
            @_renderItem ul, enhancement for enhancement in entityEnhancements
            console.info 'render', entityEnhancements
        _renderItem: (ul, enhancement) ->
            label = enhancement.get("<#{ns.enhancer}entity-label>")
            $("<li><a href='#'>#{label}</a></li>")
            .data('enhancement', enhancement)
            .appendTo ul
        _create: () ->
            @suggestion = @options.suggestion
            @element.click =>
                console.info @suggestion.getEntityEnhancements()
                ul = $('<ul></ul>')
                .appendTo( $("body")[0] )
                @_renderMenu ul, @suggestion.getEntityEnhancements()
                @menu = ul
                .menu({
                    select: (event, ui) =>
                        console.info ui.item
                        @annotate ui.item.data('enhancement'), 'acknowledged'
                        ui.item.parent().menu('destroy').html ''
                    blur: (event, ui) ->
                        console.info 'blur', ui.item
                        ui.item.parent().menu('destroy').html ''
                })
                .bind('menublur', (event, ui) ->
                    console.info 'menublur', ui.item
                    ui.item.parent().menu('destroy').html ''
                )
                .data 'menu'
                @menu.element.position {
                    of: @element
                    my: "left top"
                    at: "left bottom"
                    collision: "none"}
                console.info @menu.element

)(jQuery)
