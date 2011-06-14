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
        rdfs:     'http://www.w3.org/2000/01/rdf-schema#'

    # filter the entityManager for TextAnnotations
    getTextAnnotations = ->
        VIE.EntityManager.entities.filter (e) ->
            e.attributes["<#{ns.rdf}type>"].indexOf("#{ns.enhancer}TextAnnotation") != -1
    
    # filter the entityManager for TextAnnotations    
    getEntityAnnotations = ->
        VIE.EntityManager.entities.filter (e) ->
            e.attributes["<#{ns.rdf}type>"].indexOf("#{ns.enhancer}EntityAnnotation") != -1

    # 
    deleteEnhancements = (oldDocUri) ->
    # to be fixed
#        VIE.EntityManager.entities.each (ent) -> 
#            ent.destroy() if ent.attributes["<#{ns.enhancer}extracted-from>"] is oldDocUri
    
    # Get the label in the user's language or the first one from a VIE entity
    getRightLabel = (entity) -> 
        getLang: (label) ->
            label["xml:lang"]
        
        labelMap = {}
        for label in _(entity["#{ns.rdfs}label"]).flatten()
            labelMap[label["xml:lang"]|| "_"] = label.value
        
        userLang = window.navigator.language.split("-")[0]
        if labelMap[userLang]
            labelMap[userLang].value 
        else 
            labelMap["_"]
    
    # A suggestion object has the methods for getting generic enhancement-specific 
    # properties.
    # 
    # TODO Decouple from stanbol. Right now it works with apache stanbol only.
    Suggestion = (enhancement) -> 
        @_enhancement = enhancement
        id = @_enhancement.id
    Suggestion.prototype = 
        # the text the annotation is for
        getSelectedText: -> 
            @_enhancement
            .toJSON()["<#{ns.enhancer}selected-text>"]
        # get Entities suggested for the text enhancement (if any)
        getEntityEnhancements: ->
            _(getEntityAnnotations()).filter (ann) =>
                if _(ann.attributes["<#{ns.dc}relation>"]).flatten().indexOf(@_enhancement.id) isnt -1 then true
                else false
        # The type of the entity suggestion (e.g. person, location, organization)
        getType: ->
            @_enhancement
                .toJSON()["<#{ns.dc}type>"]
        # Get the text enhancement as JSON object
        # toJSON: ->
        #     @_enhancement.toJSON()

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
        
        el.addClass "withSuggestions" 
        # Create widget to select from the suggestions
        el.annotationSelector suggestion: suggestion
    
    # the analyze jQuery plugin runs a stanbol enhancement process
    jQuery.fn.analyze = ->
        analyzedNode = @
        # the analyzedDocUri makes the connection between a document state and 
        # the annotations to it. We have to clean up the annotations to any 
        # old document state
        
        oldDocUri = @data "analizedDocUri"
        if oldDocUri
            deleteEnhancements oldDocUri
        VIE2.connectors['stanbol'].analyze @,
            success: (rdf) =>
                # Get enhancements
                rdfJson = rdf.databank.dump()
                
                VIE.EntityManager.getByRDFJSON rdfJson
                textAnnotations = getTextAnnotations()
                docUri = _(textAnnotations).first().get "<#{ns.enhancer}extracted-from>"
                @data "analizedDocUri", docUri
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
        _create: ->
            @suggestion = @options.suggestion
            @element.click =>
                @entityEnhancements = @suggestion.getEntityEnhancements()
                console.info @entityEnhancements
                if @entityEnhancements.length > 0
                    @_createMenu()
                else
                    @_showSearchbox()
        _createMenu: ->
            ul = $('<ul></ul>')
            .appendTo( $("body")[0] )
            @_renderMenu ul, @entityEnhancements
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
        _showSearchbox: ->
            searchEntryField = $('<span style="background: fff;"><label for="search"></label><input class="search"></span>')
            .appendTo $( "body" )[0]
            searchEntryField
            .position {
                of: @element
                my: "left top"
                at: "left bottom"
                collision: "none"}
            $('.search',searchEntryField).autocomplete 
                source: (req, resp) ->
                    console.info "req:", req
                    VIE2.connectors['stanbol'].findEntity "#{req.term}#{'*' if req.term.length > 3}", (entityList) ->
                        console.info "resp:", _(entityList).map (ent) -> 
                            ent.id
                        res = for i, entity of entityList 
                            {
                            key: entity.id
                            label: getRightLabel entity
                            }
                        resp res
            console.info "show searchbox"

    # the annotationSelector makes an annotated word interactive
    jQuery.widget 'IKS.manualAnnotationLookup',
        options:
            suggestion: null
    
)(jQuery)
