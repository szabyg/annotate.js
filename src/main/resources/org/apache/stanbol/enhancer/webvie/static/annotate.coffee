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
        
    
    ANTT = ANTT or {}
    
    # filter for TextAnnotations
    ANTT.getTextAnnotations = (enhRdf) ->
        res = _(enhRdf).map((obj, key) ->
            obj.id = key
            obj
        )
        .filter (e) ->
            e["#{ns.rdf}type"]
            .map((x) -> x.value)
            .indexOf("#{ns.enhancer}TextAnnotation") != -1
        res = _(res).sortBy (e) -> 
            conf = Number e["#{ns.enhancer}confidence"][0].value if e["#{ns.enhancer}confidence"]
            -1 * conf
            
        _(res).map (s)->
            new ANTT.Suggestion s, enhRdf

    
    # filter the entityManager for TextAnnotations    
    ANTT.getEntityAnnotations = (enhRdf) ->
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
    ANTT.getRightLabel = (entity) -> 
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
    ANTT.Suggestion = (enhancement, enhRdf) -> 
        @_enhancement = enhancement
        @enhRdf = enhRdf
        @id = @_enhancement.id
    ANTT.Suggestion.prototype = 
        # the text the annotation is for
        getSelectedText: -> 
            @_vals("#{ns.enhancer}selected-text")[0]
        getConfidence: ->
            @_vals("#{ns.enhancer}confidence")[0]
        # get Entities suggested for the text enhancement (if any)
        getEntityEnhancements: ->
            rawList = _(ANTT.getEntityAnnotations @enhRdf ).filter (ann) =>
                relations = _(ann["#{ns.dc}relation"])
                .map (e) -> e.value
                if (relations.indexOf @_enhancement.id) isnt -1 then true
                else false
            _(rawList).map (ee) ->
                new ANTT.EntityEnhancement ee
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
    ANTT.EntityEnhancement = (ee) ->
        $.extend @, ee
    ANTT.EntityEnhancement.prototype =
        getLabel: ->
            @_vals("#{ns.enhancer}entity-label")[0]
        getUri: -> 
            @_vals("#{ns.enhancer}entity-reference")[0]
        getTypes: -> 
            @_vals("#{ns.enhancer}entity-type")
        getConfidence: ->
            Number @_vals("#{ns.enhancer}confidence")[0]
        _vals: (key) ->
            _(@[key]).map (x) -> x.value
    
    # get create a dom element containing only the occurrence of the found entity
    ANTT.getOrCreateDomElement = (element, text, options = {}) ->
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
    ANTT.processSuggestion = (suggestion, parentEl) ->
        el = $ ANTT.getOrCreateDomElement parentEl[0], suggestion.getSelectedText(), 
            createElement: 'span'
            createMode: 'existing'
            context: suggestion.getContext()
            start:   suggestion.getStart()
            end:     suggestion.getEnd()
        sType = suggestion.getType()
        el.addClass('entity')
        .addClass(ANTT.uriSuffix sType)
        
        el.addClass "withSuggestions" 
        # Create widget to select from the suggestions
        el.annotationSelector()
        .annotationSelector 'addSuggestion', suggestion
    ANTT.uriSuffix = (uri) ->
        uri.substring uri.lastIndexOf("/") + 1
        
    # jquery events cloning method
    ANTT.cloneCopyEvent = (src, dest) ->
        if dest.nodeType isnt 1 or not jQuery.hasData src
            return

        internalKey = $.expando
        oldData = $.data src
        curData = $.data dest, oldData
        
        # Switch to use the internal data object, if it exists, for the next
        # stage of data copying
        if oldData = oldData[internalKey]
            events = oldData.events
            curData = curData[ internalKey ] = jQuery.extend({}, oldData);

            if events
                delete curData.handle
                curData.events = {}

                `for ( var type in events ) {
                    for ( var i = 0, l = events[ type ].length; i < l; i++ ) {
                        jQuery.event.add( dest, type + ( events[ type ][ i ].namespace ? "." : "" ) + events[ type ][ i ].namespace, events[ type ][ i ], events[ type ][ i ].data );
                    }
                }`
            null
    
    # the analyze jQuery plugin runs a stanbol enhancement process
    ANTT.analyze = jQuery.fn.analyze = ->
#    jQuery.widget 'IKS.analyze',
#        options:
#            asdf: 3
#        create: ->
        analyzedNode = @
        # the analyzedDocUri makes the connection between a document state and 
        # the annotations to it. We have to clean up the annotations to any 
        # old document state
        
        VIE2.connectors['stanbol'].analyze @,
            success: (rdf) =>
                # Get enhancements
                rdfJson = rdf.databank.dump()
                
                textAnnotations = ANTT.getTextAnnotations(rdfJson)
                _(textAnnotations).each (s) ->
                    console.info s._enhancement,
                        'confidence', s.getConfidence(),
                        'selectedText', s.getSelectedText(), 
                        'type', s.getType(),
                        'EntityEnhancements', s.getEntityEnhancements()
                    ANTT.processSuggestion s, analyzedNode
    
    # the annotationSelector makes an annotated word interactive
    ANTT.annotationSelector = 
    jQuery.widget 'IKS.annotationSelector',
        options:
            suggestion: null
            ns:
                dbpedia:  "http://dbpedia.org/ontology/"
            getTypes: ->
                [
                    uri:   "#{@ns.dbpedia}Place"
                    label: 'Place'
                ,
                    uri:   "#{@ns.dbpedia}Person"
                    label: 'Person'
                ,
                    uri:   "#{@ns.dbpedia}Organisation"
                    label: 'Organisation'
                ]
            getSources: ->
                [
                    uri: "http://dbpedia.org/resource/"
                    label: "dbpedia"
                ,
                    uri: "http://sws.geonames.org/"
                    label: "geonames"
                ]
            # annotate event handler
            annotationselected: (event, ui) ->

        # Produce type label list out of a uri list.
        # Filtered by the @options.types list
        _typeLabels: (types) ->
            knownMapping = @options.getTypes()
            allKnownPrefixes = _(knownMapping).map (x) -> x.uri
            knownPrefixes = _.intersect allKnownPrefixes, types
            _(knownPrefixes).map (key) =>
                foundPrefix = _(knownMapping).detect (x) -> x.uri is key
                foundPrefix.label
        
        #
        _sourceLabel: (src) ->
            sources = @options.getSources()
            sourceObj = _(sources).detect (s) -> src.indexOf(s.uri) isnt -1
            if sourceObj
                sourceObj.label
            else
                src.split("/")[2]
        _create: ->
            @element.click =>
                @_createDialog()
#                @_createCloseButton()
                @entityEnhancements = @suggestion.getEntityEnhancements()
                console.info @entityEnhancements
                @_createSearchbox()
                if @entityEnhancements.length > 0
                    @_createMenu() if @menu is undefined
            @element.bind "annotationselected", @options.annotationselected

        _createDialog: ->
            label = @element.text()
            dialogEl = $("<div>")
            .attr( "tabIndex", -1)
            .addClass()
            .keydown( (event) =>
                if not event.isDefaultPrevented() and event.keyCode and event.keyCode is $.ui.keyCode.ESCAPE
                    console.info "dialogEl ESCAPE key event -> close"
                    @close event
                    event.preventDefault()
            )
            .bind('dialogblur', (event) =>
                console.info 'dialog dialogblur'
                @close(event)
            )
            .bind('blur', (event) =>
                console.info 'dialog blur'
                @close(event)
            )
            .appendTo( $("body")[0] )
            dialogEl.dialog
                width: 400
#                modal: true
                title: label
                close: (event, ui) =>
                    @close(event)
            @dialog = dialogEl.data 'dialog'
            console.info @dialog
            @dialog.uiDialog.position {
                of: @element
                my: "left top"
                at: "left bottom"
                collision: "none"}
            @dialog.element.focus(100)
            window.d = @dialog
            @_updateTitle()
            @_setButtons()
            
        _setButtons: ->
            @dialog.element.dialog 'option', 'buttons', 
                rem: 
                    text: if @isAnnotated() then 'Remove' else 'Decline'
                    click: =>
                        @remove()
                Cancel: =>
                    @close()
                    
        remove: ->
            el = @element.parent()
            console.info el.html()
            @element.replaceWith document.createTextNode @element.text()
            console.info el.html()
            @close()
        
        isAnnotated: ->
            if @element.attr 'about' then true else false
            
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
            ANTT.cloneCopyEvent @element[0], newElement[0]
            @linkedEntity =
                uri: entityUri
                type: entityType
            @element.replaceWith newElement
            @element = newElement.addClass styleClass
            # TODO write the fact it's acknowledged into the VIE
            console.info "created enhancement in", @element
            @_updateTitle()
            @_trigger 'annotationselected', {linkedEntity: @linkedEntity}
        close: (event) ->
            if @menu
                @menu.destroy()
                @menu.element.remove() 
                delete @menu
            @dialog.destroy()
            @dialog.element.remove()
            @dialog.uiDialogTitlebar.remove()
            delete @dialog
        _updateTitle: ->
            if @isAnnotated()
                title = "#{@element.text()} <small>at #{@_sourceLabel(@linkedEntity.uri)}</small>"
            else
                title = @element.text()
            @dialog.element.dialog 'option', 'title', title
        _createMenu: ->
            ul = $('<ul></ul>')
            .appendTo( @dialog.element )
            @_renderMenu ul, @entityEnhancements
            @menu = ul
            .menu({
                select: (event, ui) =>
                    console.info ui.item
                    @annotate ui.item.data('enhancement'), 'acknowledged'
                    @close(event)
                blur: (event, ui) ->
                    console.info 'menu.blur()', ui.item
            })
            .bind('blur', (event, ui) ->
                console.info 'menu blur', ui
            )
            .bind('menublur', (event, ui) ->
                console.info 'menu menublur', ui.item
            )
            .focus(150)
            .data 'menu'
            console.info "createMenu"
            console.info @menu.element
        _renderMenu: (ul, entityEnhancements) ->
            entityEnhancements = _(entityEnhancements).sortBy (ee) -> -1 * ee.getConfidence()
            @_renderItem ul, enhancement for enhancement in entityEnhancements
            console.info 'render', entityEnhancements
        _renderItem: (ul, enhancement) ->
            console.info 'enhancement:', enhancement, 'conf:', enhancement.getConfidence()
            label = enhancement.getLabel()
            type = @_typeLabels enhancement.getTypes()
            source = @_sourceLabel enhancement.getUri()
            $("<li><a href='#'>#{label} <small>(#{type} from #{source})</small></a></li>")
            .data('enhancement', enhancement)
            .appendTo ul
        _removeAnnotation: ->
            @element.removeAttr 'about'
            @element.removeAttr 'typeof'
        
        _createSearchbox: ->
            # Show an input box for autocompleted search
            searchEntryField = $('<span style="background: fff;"><label for="search"></label><input class="search"></span>')
            .appendTo @dialog.element
            $('.search',searchEntryField)
            .autocomplete 
                source: (req, resp) ->
                    console.info "req:", req
                    VIE2.connectors['stanbol'].findEntity "#{req.term}#{'*' if req.term.length > 3}", (entityList) ->
                        console.info "resp:", _(entityList).map (ent) -> 
                            ent.id
                        res = for i, entity of entityList 
                            {
                            key: entity.id
                            label: ANTT.getRightLabel entity
                            getUri: -> @key
                            }
                        resp res
                select: (e, ui) =>
                    console.info "select event", e, ui
                    @annotate ui.item, "acknowledged"
                    console.info e.target
            .focus(200)
            console.info "show searchbox"
        addSuggestion: (suggestion) ->
            # TODO support multiple suggestions
            @options.suggestion = suggestion
            @suggestion = @options.suggestion

    window.ANTT = ANTT
) jQuery
