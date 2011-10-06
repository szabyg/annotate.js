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
        skos:     'http://www.w3.org/2004/02/skos/core#'

    ANTT = ANTT or {}
    Stanbol = Stanbol or {}

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
            e.hasType "<#{ns.enhancer}EntityAnnotation>"

    # Get the label in the user's language or the first one from a VIE entity
    ANTT.getRightLabel = (entity) ->
        labelMap = {}
        for label in _(entity["#{ns.rdfs}label"]).flatten()
            cleanLabel = label.value
            if cleanLabel.lastIndexOf("@") is cleanLabel.length - 3
                cleanLabel = cleanLabel.substring 0, cleanLabel.length - 3
            labelMap[label["xml:lang"]|| "_"] = cleanLabel
        userLang = window.navigator.language.split("-")[0]
        # Return the first best label
        labelMap[userLang] or labelMap["_"] or labelMap["en"]

    # Generic API for a TextEnhancement
    # A TextEnhancement object has the methods for getting generic
    # text-enhancement-specific properties.
    # TODO Place it into a global Stanbol object.
    Stanbol.TextEnhancement = (enhancement, enhList) ->
        @_enhancement = enhancement
        @_enhList = enhList
        @id = @_enhancement.getSubject()
    Stanbol.TextEnhancement.prototype =
        # the text the annotation is for
        getSelectedText: ->
            @_vals("enhancer:selected-text")
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
            @_uriTrim @_vals("dc:type")
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
    Stanbol.EntityEnhancement = (ee, textEnh) ->
        @_enhancement = ee
        @_textEnhancement = textEnh
        @
    Stanbol.EntityEnhancement.prototype =
        getLabel: ->
            @_vals("enhancer:entity-label")
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

    # get or create a dom element containing only the occurrence of the found entity
    ANTT.getOrCreateDomElement = (element, text, options = {}) ->
        # Find occurrence indexes of s in str
        occurrences = (str, s) ->
            res = []
            last = 0
            while str.indexOf(s, last + 1) isnt -1
                next = str.indexOf s, last+1
                res.push next
                last = next

        # Find the nearest number among the 
        nearest = (arr, nr) ->
            _(arr).sortedIndex nr

        # Nearest position
        nearestPosition = (str, s, ind) ->
            arr = occurrences(str,s)
            i1 = nearest arr, ind
            if arr.length is 1
                arr[0]
            else if i1 is arr.length
                arr[i1-1]
            else
                i0 = i1-1
                d0 = ind - arr[i0]
                d1 = arr[i1] - ind
                if d1 > d0 then arr[i0]
                else arr[i1]

        domEl = element
        textContentOf = (element) -> $(element).text().replace(/\n/g, " ")
        # find the text node
        if textContentOf(element).indexOf(text) is -1
            throw "'#{text}' doesn't appear in the text block."
            return $()
        start = options.start +
        textContentOf(element).indexOf textContentOf(element).trim()
        # Correct small position errors
        start = nearestPosition textContentOf(element), text, start
        pos = 0
        while textContentOf(domEl).indexOf(text) isnt -1 and domEl.nodeName isnt '#text'
            domEl = _(domEl.childNodes).detect (el) ->
                p = textContentOf(el).lastIndexOf text
                if p >= start - pos
                    true
                else
                    pos += textContentOf(el).length
                    false

        if options.createMode is "existing" and textContentOf($(domEl).parent()) is text
            return $(domEl).parent()[0]
        else
            pos = start - pos
            len = text.length
            textToCut = textContentOf(domEl).substring(pos, pos+len)
            if textToCut is text
                domEl.splitText pos + len
                newElement = document.createElement options.createElement or 'span'
                newElement.innerHTML = text
                $(domEl).parent()[0].replaceChild newElement, domEl.splitText pos
                $ newElement
            else
                console.warn "dom element creation problem: #{textToCut} isnt #{text}"

    # Give back the last part of a uri for fallback label creation
    ANTT.uriSuffix = (uri) ->
        res = uri.substring uri.lastIndexOf("#") + 1
        res.substring res.lastIndexOf("/") + 1

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

                for type of events
                    i = 0
                    l = events[type].length
                    while i < l
                        jQuery.event.add dest, type + (if events[type][i].namespace then "." else "") + events[type][i].namespace, events[type][i], events[type][i].data
                        i++
            null

    ######################################################
    # Annotate widget
    # makes a content dom element interactively annotatable
    ######################################################
    jQuery.widget 'IKS.annotate',
        __widgetName: "IKS.annotate"
        options:
            autoAnalyze: false
            debug: false
            # namespaces necessary for the widget configuration
            ns:
                dbpedia:  "http://dbpedia.org/ontology/"
                skos:     "http://www.w3.org/2004/02/skos/core#"
            # Give a label to your expected enhancement types
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
                ,
                    uri:   "#{@ns.skos}Concept"
                    label: 'Concept'
                ]
            # Give a label to the sources the entities come from
            getSources: ->
                [
                    uri: "http://dbpedia.org/resource/"
                    label: "dbpedia"
                ,
                    uri: "http://sws.geonames.org/"
                    label: "geonames"
                ]
        _create: ->
            widget = @
            # logger can be turned on and off. It will show the real caller line in the log
            @_logger = if @options.debug then console else 
                info: ->
                warn: ->
                error: ->
            # widget.entityCache.get(uri, cb) will get and cache the entity from an entityhub
            @entityCache = window.entityCache =
                _entities: {}
                # calling the get with a scope and callback will call cb(entity) with the scope as soon it's available.'
                get: (uri, scope, cb) ->
                    # If entity is stored in the cache already just call cb
                    if @_entities[uri] and @_entities[uri].status is "done"
                        cb.apply scope, [@_entities[uri].entity]
                    # If the entity is new to the cache
                    else if not @_entities[uri]
                        # create cache entry
                        @_entities[uri] = 
                            status: "pending"
                            uri: uri
                        cache = @
                        # make a request to the entity hub
                        ###
                        widget.options.vie.load({entity: uri}).using('stanbol').execute().success (entity) ->
                            if not entity.status
                                if entity.id isnt uri
                                    widget._logger.warn "wrong callback", uri, entity.id
                                cache._entities[uri].entity = entity
                                cache._entities[uri].status = "done"
                                $(cache._entities[uri]).trigger "done", entity
                            else
                                widget._logger.warn "error getting entity", uri, entity
                        ###
                    if @_entities[uri] and @_entities[uri].status is "pending"
                        $( @_entities[uri] )
                        .bind "done", (event, entity) ->
                            cb.apply scope, [entity]
            if @options.autoAnalyze
                @enable()

        # analyze the widget element and show text enhancements
        enable: (cb) ->
            analyzedNode = @element
            # the analyzedDocUri makes the connection between a document state and
            # the annotations to it. We have to clean up the annotations to any
            # old document state

            @options.vie.analyze( element: @element ).using(@options.vieServices)
            .execute()
            .success (enhancements) =>
              _.defer =>
                # Link TextAnnotation entities to EntityAnnotations
                entityAnnotations = Stanbol.getEntityAnnotations(enhancements)
                for entAnn in entityAnnotations
                    textAnn = entAnn.get "dc:relation"
                    textAnn = entAnn.vie.entities.get textAnn unless textAnn instanceof Backbone.Model
                    continue unless textAnn
                    _(_.flatten([textAnn])).each (ta) ->
                        ta.set
                            "entityAnnotation": entAnn.getSubject()
                # Get enhancements
                textAnnotations = Stanbol.getTextAnnotations(enhancements)
                # Remove all textAnnotations without a selected text property
                textAnnotations = _(textAnnotations)
                .filter (textEnh) ->
                    if textEnh.getSelectedText and textEnh.getSelectedText()
                        true
                    else
                        false
                _(textAnnotations)
                .each (s) =>
                    @_logger.info s._enhancement,
                        'confidence', s.getConfidence(),
                        'selectedText', s.getSelectedText(),
                        'type', s.getType(),
                        'EntityEnhancements', s.getEntityEnhancements()
                    # Process the text enhancements
                    @processTextEnhancement s, analyzedNode
                # trigger 'done' event with success = true
                @_trigger "done", true
                if typeof cb is "function"
                    cb true
            .fail (xhr)->
                cb false
                console.error "analyze failed", xhr.responseText, xhr
        # Remove all not accepted text enhancement widgets
        disable: ->
            $( ':IKS-annotationSelector', @element ).each () ->
                $(@).annotationSelector 'disable' if $(@).data().annotationSelector

        acceptAll: (reportCallback) ->
            report = {updated: [], accepted: 0}
            $( ':IKS-annotationSelector', @element ).each () ->
                if $(@).data().annotationSelector
                    res = $(@).annotationSelector 'acceptBestCandidate'
                    if res
                        report.updated.push @
                        report.accepted++
            reportCallback report

        # processTextEnhancement deals with one TextEnhancement in an ancestor element of its occurrence
        processTextEnhancement: (textEnh, parentEl) ->
            if not textEnh.getSelectedText()
                console.warn "textEnh", textEnh, "doesn't have selected-text!"
                return
            el = $ ANTT.getOrCreateDomElement parentEl[0], textEnh.getSelectedText(),
                createElement: 'span'
                createMode: 'existing'
                context: textEnh.getContext()
                start:   textEnh.getStart()
                end:     textEnh.getEnd()
            sType = textEnh.getType() or "Other"
            widget = @
            el.addClass('entity')
            for type in sType
                el.addClass ANTT.uriSuffix(type).toLowerCase()
            if textEnh.getEntityEnhancements().length
                el.addClass "withSuggestions"
            for eEnh in textEnh.getEntityEnhancements()
                eEnhUri = eEnh.getUri()
                @entityCache.get eEnhUri, eEnh, (entity) ->
                    if this.getUri() isnt entity.id
                        widget._logger.warn "wrong callback", entity.id, this.getUri()
#                    widget._logger.info "entity for", textEnh.getSelectedText(), this.getUri(), entity
            # Create widget to select from the suggested entities
            options =
                cache: @entityCache
            $.extend options, @options
            el.annotationSelector( options )
            .annotationSelector 'addTextEnhancement', textEnh

    ######################################################
    # AnnotationSelector widget
    # the annotationSelector makes an annotated word interactive
    ######################################################
    ANTT.annotationSelector =
    jQuery.widget 'IKS.annotationSelector',
        # just for debugging and understanding
        __widgetName: "IKS.annotationSelector"
        options:
            ns:
                dbpedia:  "http://dbpedia.org/ontology/"
                skos:     "http://www.w3.org/2004/02/skos/core#"
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
                ,
                    uri:   "#{@ns.skos}Concept"
                    label: 'Concept'
                ]
            getSources: ->
                [
                    uri: "http://dbpedia.org/resource/"
                    label: "dbpedia"
                ,
                    uri: "http://sws.geonames.org/"
                    label: "geonames"
                ]

        _create: ->
            @element.click (e) =>
                console.log "click", e, e.isDefaultPrevented()
                e.preventDefault()
                if not @dialog
                    @_createDialog()
                    setTimeout((=> @dialog.open()), 220)

                    @entityEnhancements = @_getEntityEnhancements()

                    @_createSearchbox()
                    if @entityEnhancements.length > 0
                        @_createMenu() if @menu is undefined
                else @searchEntryField.find('.search').focus 100
            @_logger = if @options.debug then console else 
                info: ->
                warn: ->
                error: ->
        _destroy: ->
            if @menu
                @menu.destroy()
                @menu.element.remove()
                delete @menu
            if @dialog
                @dialog.destroy()
                @dialog.element.remove()
                @dialog.uiDialogTitlebar.remove()
                delete @dialog

        _getEntityEnhancements: ->
            # Collect all EntityEnhancements for all the TextEnhancements
            # on the selected node.
            eEnhancements = []
            for textEnh in @textEnhancements
                for enhancement in textEnh.getEntityEnhancements()
                    eEnhancements.push enhancement
            # filter enhancements with the same uri
            # this is necessary because of a bug in stanbol that creates
            # duplicate enhancements.
            # https://issues.apache.org/jira/browse/STANBOL-228
            _tempUris = []
            eEnhancements = _(eEnhancements).filter (eEnh) ->
                uri = eEnh.getUri()
                if _tempUris.indexOf(uri) is -1
                    _tempUris.push uri
                    true
                else
                    false
            _(eEnhancements).sortBy (e) ->
                -1 * e.getConfidence()

        # Produce type label list out of a uri list.
        # Filtered by the @options.types list
        _typeLabels: (types) ->
            knownMapping = @options.getTypes()
            allKnownPrefixes = _(knownMapping).map (x) -> x.uri
            knownPrefixes = _.intersect allKnownPrefixes, types
            _(knownPrefixes).map (key) =>
                foundPrefix = _(knownMapping).detect (x) -> x.uri is key
                foundPrefix.label

        # make a label for the entity source based on options.getSources()
        _sourceLabel: (src) ->
            console.warn "No source" unless src
            return "" unless src
            sources = @options.getSources()
            sourceObj = _(sources).detect (s) -> src.indexOf(s.uri) isnt -1
            if sourceObj
                sourceObj.label
            else
                src.split("/")[2]

        # create dialog widget
        _createDialog: ->
            label = @element.text()
            dialogEl = $("<div><span class='entity-link'></span></div>")
            .attr( "tabIndex", -1)
            .addClass()
            .keydown( (event) =>
                if not event.isDefaultPrevented() and event.keyCode and event.keyCode is $.ui.keyCode.ESCAPE
                    @close event
                    event.preventDefault()
            )
            .bind('dialogblur', (event) =>
                @_logger.info 'dialog dialogblur'
                @close(event)
            )
            .bind('blur', (event) =>
                @_logger.info 'dialog blur'
                @close(event)
            )
            .appendTo( $("body")[0] )
            widget = @
            dialogEl.dialog
                width: 400
                title: label
                close: (event, ui) =>
                    @close(event)
                autoOpen: false
                open: (e, ui) ->
                    $.data(this, 'dialog').uiDialog.position {
                        of: widget.element
                        my: "left top"
                        at: "left bottom"
                        collision: "none"}
            @dialog = dialogEl.data 'dialog'
            @dialog.uiDialogTitlebar.hide()
            @_logger.info "dialog widget:", @dialog
            @dialog.element.focus(100)
            window.d = @dialog
            @_insertLink()
            @_updateTitle()
            @_setButtons()

        # If annotation is already made insert a link to the entity
        _insertLink: ->
            if @isAnnotated() and @dialog
                $("Annotated: <a href='#{@linkedEntity.uri}' target='_blank'>
                #{@linkedEntity.label} @ #{@_sourceLabel(@linkedEntity.uri)}</a><br/>")
                .appendTo $( '.entity-link', @dialog.element )
        # create/update the dialog button row
        _setButtons: ->
            @dialog.element.dialog 'option', 'buttons',
                rem:
                    text: if @isAnnotated() then 'Remove' else 'Decline'
                    click: (event) =>
                        @remove event
                Cancel: =>
                    @close()

        # remove textEnhancement/annotation, replace the separate html
        # element with the plain text and close the dialog
        remove: (event) ->
            el = @element.parent()
            if not @isAnnotated() and @textEnhancements
                @_trigger 'decline', event,
                    textEnhancements: @textEnhancements
            else
                @_trigger 'remove', event,
                    textEnhancement: @_acceptedTextEnhancement
                    entityEnhancement: @_acceptedEntityEnhancement
                    linkedEntity: @linkedEntity
            @destroy()
            if @element.qname().name isnt '#text'
                @element.replaceWith document.createTextNode @element.text()

        # Remove the widget if not annotated.
        disable: ->
            if not @isAnnotated() and @element.qname().name isnt '#text'
                @element.replaceWith document.createTextNode @element.text()

        # tells if this is an annotated dom element (not a highlighted textEnhancement only)
        isAnnotated: ->
            if @element.attr 'about' then true else false

        # Place the annotation on the DOM element (about and typeof attributes)
        annotate: (entityEnhancement, options) ->
            entityUri = entityEnhancement.getUri()
            entityType = entityEnhancement.getTextEnhancement().getType() or ""
            entityHtml = @element.html()
            # We ignore the old style classes
            # entityClass = @element.attr 'class'
            sType = entityEnhancement.getTextEnhancement().getType()
            sType = ["Other"] unless sType.length
            rel = options.rel or "#{ns.skos}related"
            entityClass = 'entity ' + ANTT.uriSuffix(sType[0]).toLowerCase()
            newElement = $ "<a href='#{entityUri}'
                about='#{entityUri}'
                typeof='#{entityType}'
                rel='#{rel}'
                class='#{entityClass}'>#{entityHtml}</a>"
            ANTT.cloneCopyEvent @element[0], newElement[0]
            @linkedEntity =
                uri: entityUri
                type: entityType
                label: entityEnhancement.getLabel()
            @element.replaceWith newElement
            @element = newElement.addClass options.styleClass
            @_logger.info "created annotation in", @element
            @_updateTitle()
            @_insertLink()
            @_acceptedTextEnhancement = entityEnhancement.getTextEnhancement()
            @_acceptedEntityEnhancement = entityEnhancement
            @_trigger 'select', null,
                linkedEntity: @linkedEntity
                textEnhancement: entityEnhancement.getTextEnhancement()
                entityEnhancement: entityEnhancement

        acceptBestCandidate: ->
            eEnhancements = @_getEntityEnhancements()
            return unless eEnhancements.length
            return if @isAnnotated()
            @annotate eEnhancements[0], styleClass: "acknowledged"
            eEnhancements[0]

        # closing the widget
        close: ->
            @destroy()
        _updateTitle: ->
            if @dialog
                if @isAnnotated()
                    title = "#{@linkedEntity.label} <small>@ #{@_sourceLabel(@linkedEntity.uri)}</small>"
                else
                    title = @element.text()
                @dialog._setOption 'title', title

        # create menu and add to the dialog
        _createMenu: ->
            ul = $('<ul></ul>')
            .appendTo( @dialog.element )
            @_renderMenu ul, @entityEnhancements
            @menu = ul
            .menu({
                select: (event, ui) =>
                    @_logger.info "selected menu item", ui.item
                    @annotate ui.item.data('enhancement'), styleClass: 'acknowledged'
                    @close(event)
                blur: (event, ui) =>
                    @_logger.info 'menu.blur()', ui.item
                focus: (event, ui) =>
                    @_logger.info 'menu.focus()', ui.item
                    # show preview
                    @_entityPreview ui.item
            })
            .bind('blur', (event, ui) ->
                @_logger.info 'menu blur', ui
            )
            .bind('menublur', (event, ui) ->
                @_logger.info 'menu menublur', ui.item
            )
            .focus(150)
            .data 'menu'

        # Rendering menu for the EntityEnhancements suggested for the selected text
        _renderMenu: (ul, entityEnhancements) ->
            entityEnhancements = _(entityEnhancements).sortBy (ee) -> -1 * ee.getConfidence()
            @_renderItem ul, enhancement for enhancement in entityEnhancements
            @_logger.info 'rendered menu for the elements', entityEnhancements
        _renderItem: (ul, eEnhancement) ->
            label = eEnhancement.getLabel().replace /^\"|\"$/g, ""
            type = @_typeLabels(eEnhancement.getTypes()).toString() or "Other"
            source = @_sourceLabel eEnhancement.getUri()
            active = if @linkedEntity and eEnhancement.getUri() is @linkedEntity.uri
                    " class='ui-state-active'"
                else ""
            $("<li#{active}><a href='#'>#{label} <small>(#{type} from #{source})</small></a></li>")
            .data('enhancement', eEnhancement)
            .appendTo ul

        # Render search box with autocompletion for finding the right entity
        _createSearchbox: ->
            # Show an input box for autocompleted search
            @searchEntryField = $('<span style="background: fff;"><label for="search">Search:</label> <input id="search" class="search"></span>')
            .appendTo @dialog.element
            sugg = @textEnhancements[0]
            widget = @
            $( '.search', @searchEntryField )
            .autocomplete
                # Define source method. TODO make independent from stanbol.
                source: (req, resp) ->
                    widget._logger.info "req:", req
                    widget.options.vie.find({term: "#{req.term}#{if req.term.length > 3 then '*'  else ''}"})
                    .using('stanbol').execute()
                    .fail (e) ->
                        widget._logger.error "Something wrong happened at stanbol find:", e
                    .success (entityList) ->
                      _.defer =>
                        widget._logger.info "resp:", _(entityList).map (ent) ->
                            ent.id
                        limit = 10
                        entityList = _(entityList).filter (ent) ->
                            return false if ent.id is "http://www.iks-project.eu/ontology/rick/query/QueryResultSet"
                            return true
                        res = _(entityList.slice(0, limit)).map (entity) ->
                            return {
                                key: entity.id
                                label: "#{ANTT.getRightLabel entity} @ #{widget._sourceLabel entity.id}"
                                _label: ANTT.getRightLabel entity
                                getLabel: -> @_label
                                getUri: -> @key
                                # To rethink: The type of the annotation (person, place, org)
                                # should come from the search result, not from the first textEnhancement
                                _tEnh: sugg
                                getTextEnhancement: -> @_tEnh
                            }
                        resp res
                # An entity selected, annotate
                select: (e, ui) =>
                    @annotate ui.item, styleClass: "acknowledged"
                    @_logger.info "autocomplete.select", e.target, ui
                focus: (e, ui) =>
                    @_logger.info "autocomplete.focus", e.target, ui
                    @_entityPreview ui.item
            .focus(200)
            .blur (e, ui) =>
                @_dialogCloseTimeout = setTimeout ( => @close()), 200
            @_logger.info "show searchbox"
        # Show preview of a hovered item
        _entityPreview: _.throttle(( (item) ->
            @_logger.info "Show preview for", item
        ), 1500)

        # add a textEnhancement that gets shown when the dialog is rendered
        addTextEnhancement: (textEnh) ->
            @options.textEnhancements = @options.textEnhancements or []
            @options.textEnhancements.push textEnh
            @textEnhancements = @options.textEnhancements

    window.ANTT = ANTT
) jQuery
