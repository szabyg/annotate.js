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
    getTextAnnotations = (enhRdf) ->
        res = _(enhRdf).map((obj, key) ->
            obj.id = key
            obj
        )
        .filter (e) ->
            e["#{ns.rdf}type"]
            .map((x) -> x.value)
            .indexOf("#{ns.enhancer}TextAnnotation") != -1
        _(res).sortBy (e) -> 
            conf = Number e["#{ns.enhancer}confidence"][0].value if e["#{ns.enhancer}confidence"]
            -1 * conf
    
    # filter the entityManager for TextAnnotations    
    getEntityAnnotations = (enhRdf) ->
        _(enhRdf)
        .map((obj, key) ->
            obj.id = key
            obj
        )
        .filter (e) ->
            e["#{ns.rdf}type"]
            .map((x) -> x.value)
            .indexOf("#{ns.enhancer}EntityAnnotation") != -1

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
    
    # Generic API for a TextEnhancement
    # A suggestion object has the methods for getting generic 
    # text-enhancement-specific properties.
    # 
    # TODO Place it into a global Stanbol object. 
    Suggestion = (enhancement, enhRdf) -> 
        @_enhancement = enhancement
        @enhRdf = enhRdf
        @id = @_enhancement.id
    Suggestion.prototype = 
        # the text the annotation is for
        getSelectedText: -> 
            @_vals("#{ns.enhancer}selected-text")[0]
        getConfidence: ->
            @_vals("#{ns.enhancer}confidence")[0]
        # get Entities suggested for the text enhancement (if any)
        getEntityEnhancements: ->
            rawList = _(getEntityAnnotations @enhRdf ).filter (ann) =>
                relations = _(ann["#{ns.dc}relation"])
                .map (e) -> e.value
                if (relations.indexOf @_enhancement.id) isnt -1 then true
                else false
            _(rawList).map (ee) ->
                new EntityEnhancement ee
        # The type of the entity suggestion (e.g. person, location, organization)
        getType: ->
            @_vals("#{ns.dc}type")[0]
        getContext: ->
            @_vals("#{ns.enhancer}selection-context")[0]
        getStart: ->
            Number @_vals("#{ns.enhancer}start")[0]
        getEnd: ->
            Number @_vals("#{ns.enhancer}end")[0]
        _vals: (key) ->
            _(@_enhancement[key])
            .map (x) -> x.value
    
    # Generic API for an EntityEnhancement. This is the implementation for Stanbol
    EntityEnhancement = (ee) ->
        $.extend @, ee
    EntityEnhancement.prototype =
        getLabel: ->
            @_vals("#{ns.enhancer}entity-label")[0]
        getUri: -> 
            @_vals("#{ns.enhancer}entity-reference")[0]
        _vals: (key) ->
            _(@[key]).map (x) -> x.value
    
    # get create a dom element containing only the occurrence of the found entity
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
        
        VIE2.connectors['stanbol'].analyze @,
            success: (rdf) =>
                # Get enhancements
                rdfJson = rdf.databank.dump()
                
                textAnnotations = getTextAnnotations(rdfJson)
                jQuery.each textAnnotations, ->
                    s = new Suggestion @, rdfJson
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
        _create: ->
            @element.click =>
                @entityEnhancements = @suggestion.getEntityEnhancements()
                console.info @entityEnhancements
                if @entityEnhancements.length > 0
                    @_createMenu() if @menu is undefined
                else
                    @_createSearchbox()

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
        _renderMenu: (ul, entityEnhancements) ->
            @_renderItem ul, enhancement for enhancement in entityEnhancements
            console.info 'render', entityEnhancements
        _renderItem: (ul, enhancement) ->
            label = enhancement.getLabel()
            $("<li><a href='#'>#{label}</a></li>")
            .data('enhancement', enhancement)
            .appendTo ul

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
    
) jQuery
