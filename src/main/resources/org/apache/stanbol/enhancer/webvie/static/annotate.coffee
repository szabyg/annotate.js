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
        all = VIE.EntityManager.entities.filter (e) ->
            e.attributes["<#{ns.rdf}type>"].indexOf("#{ns.enhancer}TextAnnotation") != -1
        all = _(all).sortBy (e) -> -1 * Number e.attributes["<#{ns.enhancer}confidence>"]
        # remove duplicates on selected text
    
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
            @_enhancement.toJSON()["<#{ns.enhancer}selected-text>"]
        getConfidence: ->
            @_enhancement.toJSON()["<#{ns.enhancer}confidence>"]
        # get Entities suggested for the text enhancement (if any)
        getEntityEnhancements: ->
            _(getEntityAnnotations()).filter (ann) =>
                if _([ann.attributes["<#{ns.dc}relation>"]]).flatten().indexOf(@_enhancement.id) isnt -1 then true
                else false
        # The type of the entity suggestion (e.g. person, location, organization)
        getType: ->
            @_enhancement.toJSON()["<#{ns.dc}type>"]
        getContext: ->
            @_enhancement.toJSON()["<#{ns.enhancer}selection-context>"]
        getStart: ->
            Number @_enhancement.toJSON()["<#{ns.enhancer}start>"]
        getEnd: ->
            Number @_enhancement.toJSON()["<#{ns.enhancer}end>"]

    # get create a dom element containing only the occurrence of the found entity
    # (getOrCreateDomElement is to be implemented)

    getOrCreateDomElement = (element, text, options = {}) ->
        domEl = element
        # find the text node
        textContentOf = (element) -> element.textContent.replace(/\n/g, " ")
        if(textContentOf(element).indexOf(text) is -1)
            throw "'#{text}' doesn't appear in the text block."
            return $()
        start = options.start + 
        textContentOf(element).indexOf textContentOf(element).trim()
        pos = 0
        while textContentOf(domEl).indexOf(text) isnt -1 and domEl.nodeName isnt '#text'
            domEl = _(domEl.childNodes).detect (el) ->
                p = textContentOf(el).lastIndexOf text
                if p >= start - pos
                    true
                else
                    pos += textContentOf(el).length
                    false

        if options.createMode is "existing" and textContentOf(domEl.parentElement) is text
            return domEl.parentElement
        else
            pos = start - pos
            len = text.length
            domEl.splitText pos + len
            newElement = document.createElement options.createElement or 'span'
            newElement.innerHTML = text
            domEl.parentElement.replaceChild newElement, domEl.splitText pos
            return $ newElement
    
    # processSuggestion deals with one suggestion in an ancestor element of its occurrence
    processSuggestion = (suggestion, parentEl) ->
        el = $ getOrCreateDomElement parentEl[0], suggestion.getSelectedText(), 
            createElement: 'span'
            createMode: 'existing'
            context: suggestion.getContext()
            start:   suggestion.getStart()
            end:     suggestion.getEnd()
        sType = suggestion.getType()
        el.addClass('entity')
        .addClass(sType.substring(sType.lastIndexOf("/")+1))
        
        el.addClass "withSuggestions" 
        # Create widget to select from the suggestions
        el.annotationSelector()
        .annotationSelector 'addSuggestion', suggestion
    
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
                        'confidence', s.getConfidence(),
                        'selectedText', s.getSelectedText(), 
                        'type', s.getType(),
                        'EntityEnhancements', s.getEntityEnhancements()
                    processSuggestion s, analyzedNode
    
    # the annotationSelector makes an annotated word interactive
    jQuery.widget 'IKS.annotationSelector',
        options:
            suggestion: null
        # Place the annotation on the DOM element (about and typeof attributes)
        annotate: (entityEnhancement, styleClass) ->
            entityUri = entityEnhancement.getUri()
            entityType = @suggestion.getType()
            entityHtml = @element.html()
            entityClass = @element.attr 'class'
            newElement = $ "<a href='#{entityUri}' 
                about='#{entityUri}' 
                typeof='#{entityType}'
                class='#{entityClass}'>#{entityHtml}</a>"
            @element.replaceWith newElement
            @element = newElement.addClass styleClass
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
            # the annotate method needs a getter for the uri
            enhancement.getUri = -> @get "<#{ns.enhancer}entity-reference>"
        _create: ->
            @element.click =>
                @entityEnhancements = @suggestion.getEntityEnhancements()
                console.info @entityEnhancements
                if @entityEnhancements.length > 0
                    @_createMenu() if @menu is undefined
                else
                    @_createSearchbox()
        _createMenu: ->
            ul = $('<ul></ul>')
            .appendTo( $("body")[0] )
            @_renderMenu ul, @entityEnhancements
            @menu = ul
            .menu({
                select: (event, ui) =>
                    console.info ui.item
                    @annotate ui.item.data('enhancement'), 'acknowledged'
                    ui.item.parent().menu('destroy')
                    .remove()
                    delete @menu
                blur: (event, ui) ->
                    console.info 'blur', ui.item
                    ui.item.parent().menu('destroy')
                    .remove()
            })
            .bind('menublur', (event, ui) ->
                console.info 'menublur', ui.item
                ui.item.parent().menu('destroy').html ''
            )
            .focus()
            .data 'menu'
            console.info "createMenu"
            @menu.element.position {
                of: @element
                my: "left top"
                at: "left bottom"
                collision: "none"}
            console.info @menu.element

        _createSearchbox: ->
            # Show an input box for autocompleted search
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
                            getUri: -> @key
                            }
                        resp res
                select: (e, ui) =>
                    console.info "select event", e, ui
                    @annotate ui.item, "acknowledged"
                    console.info e.target
                    $(e.target).remove()
            .blur (e) ->
                console.info "blur event", e, $(e.target)
                $(e.target)
                .autocomplete('option', 'destroy')
                .parent().remove()
            .trigger 'focus'
            console.info "show searchbox"
        addSuggestion: (suggestion) ->
            # TODO support multiple suggestions
            @options.suggestion = suggestion
            @suggestion = @options.suggestion

    # the annotationSelector makes an annotated word interactive
    jQuery.widget 'IKS.manualAnnotationLookup',
        options:
            suggestion: null
    
)(jQuery)
