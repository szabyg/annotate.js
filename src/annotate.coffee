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

    vie = new VIE()
    vie.use(new vie.StanbolService({
        url : "http://dev.iks-project.eu:8080",
        proxyDisabled: true
    }));


    ANTT ?= {}
    Stanbol ?= {}
    window.entityCache = {}

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
            @_vals("enhancer:entity-label").replace(/(^\"*|\"*@..$)/g,"")
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
            console.error "'#{text}' doesn't appear in the text block."
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
            vie: vie
            vieServices: ["stanbol"]
            autoAnalyze: false
            showTooltip: true
            debug: false
            depictionProperties: [
                "foaf:depiction"
                "schema:thumbnail"
            ]
            labelProperties: [
                "rdfs:label"
                "skos:prefLabel"
                "schema:name"
                "foaf:name"
            ]
            descriptionProperties: [
                "rdfs:comment"
                "skos:note"
                "schema:description"
                "skos:definition"
                    property: "skos:broader"
                    makeLabel: (propertyValueArr) ->
                        labels = _(propertyValueArr).map (termUri) ->
                            # extract the last part of the uri
                            termUri
                            .replace(/<.*[\/#](.*)>/, "$1")
                            .replace /_/g, "&nbsp;"
                        "Subcategory of #{labels.join ', '}."
                ,
                    property: "dc:subject"
                    makeLabel: (propertyValueArr) ->
                        labels = _(propertyValueArr).map (termUri) ->
                            # extract the last part of the uri
                            termUri
                            .replace(/<.*[\/#](.*)>/, "$1")
                            .replace /_/g, "&nbsp;"
                        "Subject(s): #{labels.join ', '}."
            ]
            fallbackLanguage: "en"
            # namespaces necessary for the widget configuration
            ns:
                dbpedia:  "http://dbpedia.org/ontology/"
                skos:     "http://www.w3.org/2004/02/skos/core#"
            typeFilter: null
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
            @entityCache = 
                _entities: -> window.entityCache
                # calling the get with a scope and callback will call cb(entity) with the scope as soon it's available.'
                get: (uri, scope, success, error) ->
                    uri = uri.replace /^<|>$/g, ""
                    # If entity is stored in the cache already just call cb
                    if @_entities()[uri] and @_entities()[uri].status is "done"
                        if typeof success is "function"
                            success.apply scope, [@_entities()[uri].entity]
                    else if @_entities()[uri] and @_entities()[uri].status is "error"
                        if typeof error is "function"
                            error.apply scope, ["error"]
                    # If the entity is new to the cache
                    else if not @_entities()[uri]
                        # create cache entry
                        @_entities()[uri] = 
                            status: "pending"
                            uri: uri
                        cache = @
                        # make a request to the entity hub
                        widget.options.vie.load({entity: uri}).using('stanbol').execute().success (entityArr) =>
                            _.defer =>
                                cacheEntry = @_entities()[uri]
                                entity = _.detect entityArr, (e) ->
                                    true if e.getSubject() is "<#{uri}>"
                                if entity
                                    cacheEntry.entity = entity
                                    cacheEntry.status = "done"
                                    $(cacheEntry).trigger "done", entity
                                else
                                    widget._logger.warn "couldn''t load #{uri}", entityArr
                                    cacheEntry.status = "not found"
                        .fail (e) =>
                            _.defer =>
                                widget._logger.error "couldn't load #{uri}"
                                cacheEntry = @_entities()[uri]
                                cacheEntry.status = "error"
                                $(cacheEntry).trigger "fail", e

                    if @_entities()[uri] and @_entities()[uri].status is "pending"
                        $( @_entities()[uri] )
                        .bind "done", (event, entity) ->
                            if typeof success is "function"
                                success.apply scope, [entity]
                        .bind "fail", (event, error) ->
                            if typeof error is "function"
                                error.apply scope, [error]
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
                    textAnns = entAnn.get "dc:relation"
                    for textAnn in _.flatten([textAnns])
                        textAnn = entAnn.vie.entities.get textAnn unless textAnn instanceof Backbone.Model
                        continue unless textAnn
                        _(_.flatten([textAnn])).each (ta) ->
                            ta.setOrAdd
                                "entityAnnotation": entAnn.getSubject()
                # Get enhancements
                textAnnotations = Stanbol.getTextAnnotations(enhancements)
                textAnnotations = @_filterByType textAnnotations
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
                @_trigger "success", true
                cb true if typeof cb is "function"
            .fail (xhr) =>
                cb false, xhr if typeof cb is "function"
                @_trigger 'error', xhr
                @_logger.error "analyze failed", xhr.responseText, xhr
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
                @_logger.warn "textEnh", textEnh, "doesn't have selected-text!"
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
                @entityCache.get eEnhUri, eEnh, (entity) =>
                    if "<#{eEnhUri}>" is entity.getSubject()
                        @_logger.info "entity #{eEnhUri} is loaded:",
                            entity.as "JSON"
                    else
                        widget._logger.warn "wrong callback", entity.getSubject(), eEnhUri
            # Create widget to select from the suggested entities
            options = @options
            options.cache = @entityCache
            el.annotationSelector( options )
            .annotationSelector 'addTextEnhancement', textEnh
        _filterByType: (textAnnotations) ->
            return textAnnotations unless @options.typeFilter
            _.filter textAnnotations, (ta) =>
                return yes if @options.typeFilter in ta.getType()
                for type in @options.typeFilter
                    return yes if type in ta.getType()

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
                @_logger.log "click", e, e.isDefaultPrevented()
#                e.preventDefault()
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
            if @isAnnotated()
                @_initTooltip()
                @linkedEntity =
                    uri: @element.attr "about"
                    type: @element.attr "typeof"
                @options.cache.get @linkedEntity.uri, @, (cachedEntity) =>
                    userLang = window.navigator.language.split("-")[0]
                    @linkedEntity.label = _(cachedEntity.get("rdfs:label"))
                    .detect((label) =>
                        if label.indexOf("@#{userLang}") > -1
                            true
                    )
                    .replace /(^\"*|\"*@..$)/g, ""
                    @_logger.info "did I figure out?", @linkedEntity.label
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
        _initTooltip: ->
            widget = @
            if @options.showTooltip
                jQuery(@element).tooltip
                    items: "[about]"
                    hide: 
                        effect: "hide"
                        delay: 50
                    show:
                        effect: "show"
                        delay: 50
                    content: (response) =>
                        uri = @element.attr "about"
                        @_logger.info "ttooltip uri:", uri
                        widget._createPreview uri, response
                        "loading..."

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
            @element.tooltip "destroy"
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
            @_initTooltip()

        acceptBestCandidate: ->
            eEnhancements = @_getEntityEnhancements()
            return unless eEnhancements.length
            return if @isAnnotated()
            @annotate eEnhancements[0], styleClass: "acknowledged"
            eEnhancements[0]

        # closing the widget
        close: ->
            @destroy()
            jQuery(".ui-tooltip").remove()
        _updateTitle: ->
            if @dialog
                if @isAnnotated()
                    title = "#{@linkedEntity.label} <small>@ #{@_sourceLabel(@linkedEntity.uri)}</small>"
                else
                    title = @element.text()
                @dialog._setOption 'title', title

        # create menu and add to the dialog
        _createMenu: ->
            widget = @
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
            })
            .bind('blur', (event, ui) ->
                @_logger.info 'menu blur', ui
            )
            .bind('menublur', (event, ui) ->
                @_logger.info 'menu menublur', ui.item
            )
            .focus(150)
            if @options.showTooltip
                @menu.tooltip
                    items: ".ui-menu-item"
                    hide: 
                        effect: "hide"
                        delay: 50
                    show:
                        effect: "show"
                        delay: 50
                    content: (response) ->
                        uri = jQuery( @ ).attr "entityuri"
                        widget._createPreview uri, response
                        "loading..."
            @menu = @menu.data 'menu'
        _createPreview: (uri, response) ->
            success = (cacheEntity) =>
                html = ""
                picSize = 100
                depictionUrl = @_getDepiction cacheEntity, picSize
                if depictionUrl
                    html += "<img style='float:left;padding: 5px;width: #{picSize}px' src='#{depictionUrl.substring 1, depictionUrl.length-1}'/>"
                descr = @_getDescription cacheEntity
                unless descr
                    @_logger.warn "No description found for", cacheEntity
                    descr = "No description found."
                html += "<div style='padding 5px;width:250px;float:left;'><small>#{descr}</small></div>"
                @_logger.info "tooltip for #{uri}: cacheEntry loaded", cacheEntity
                # workaround for a tooltip widget bug
                setTimeout ->
                    response html
                , 200

            fail = (e) =>
                @_logger.error "error loading #{uri}", e
                response "error loading entity for #{uri}"
            jQuery(".ui-tooltip").remove()
            @options.cache.get uri, @, success, fail

        _getUserLang: ->
            window.navigator.language.split("-")[0]
        _getDepiction: (entity, picSize) ->
            preferredFields = @options.depictionProperties
            # field is the first property name with a value
            field = _(preferredFields).detect (field) ->
                true if entity.get field
            # fieldValue is an array of at least one value
            if field && fieldValue = _([entity.get field]).flatten()
                # 
                depictionUrl = _(fieldValue).detect (uri) ->
                    true if uri.indexOf("thumb") isnt -1
                .replace /[0-9]{2..3}px/, "#{picSize}px"
                depictionUrl

        _getLabel: (entity) ->
            preferredFields = @options.labelProperties
            preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
            @_getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

        _getDescription: (entity) ->
            preferredFields = @options.descriptionProperties
            preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
            @_getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

        _getPreferredLangForPreferredProperty: (entity, preferredFields, preferredLanguages) ->
            # Try to find a label in the preferred language
            for lang in preferredLanguages
                for property in preferredFields
                    # property can be a string e.g. "skos:prefLabel"
                    if typeof property is "string" and entity.get property
                        labelArr = _.flatten [entity.get property]
                        # select the label in the user's language
                        label = _(labelArr).detect (label) =>
                            true if label.indexOf("@#{lang}") > -1
                        if label
                            return label.replace /(^\"*|\"*@..$)/g, ""
                    # property can be an object like {property: "skos:broader", makeLabel: function(propertyValueArr){return "..."}}
                    else if typeof property is "object" and entity.get property.property
                        valueArr = _.flatten [entity.get property.property]
                        valueArr = _(valueArr).map (termUri) ->
                            if termUri.isEntity then termUri.getSubject() else termUri
                        return property.makeLabel valueArr
            ""

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
            item = $("<li#{active} entityuri='#{eEnhancement.getUri()}'><a>#{label} <small>(#{type} from #{source})</small></a></li>")
            .data('enhancement', eEnhancement)
            .appendTo ul

        # Render search box with autocompletion for finding the right entity
        _createSearchbox: ->
            # Show an input box for autocompleted search
            @searchEntryField = $('<span style="background: fff;"><label for="search">Search:</label> <input id="search" class="search"></span>')
            .appendTo @dialog.element
            sugg = @textEnhancements[0]
            widget = @
            @searchbox = $( '.search', @searchEntryField )
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
                            return false if ent.getSubject().replace(/^<|>$/g, "") is "http://www.iks-project.eu/ontology/rick/query/QueryResultSet"
                            return true
                        res = _(entityList.slice(0, limit)).map (entity) ->
                            return {
                                key: entity.getSubject().replace /^<|>$/g, ""
                                label: "#{widget._getLabel entity} @ #{widget._sourceLabel entity.id}"
                                _label: widget._getLabel entity
                                getLabel: -> @_label
                                getUri: -> @key
                                # To rethink: The type of the annotation (person, place, org)
                                # should come from the search result, not from the first textEnhancement
                                _tEnh: sugg
                                getTextEnhancement: -> @_tEnh
                            }
                        resp res
                open: (e, ui) ->
                    widget._logger.info "autocomplete.open", e, ui
                    if widget.options.showTooltip
                        $(this).data().autocomplete.menu.activeMenu
                        .tooltip
                            items: ".ui-menu-item"
                            hide: 
                                effect: "hide"
                                delay: 50
                            show:
                                effect: "show"
                                delay: 50
                            content: (response) ->
                                uri = $( @ ).data()["item.autocomplete"].getUri()
                                widget._createPreview uri, response
                                "loading..."
                # An entity selected, annotate
                select: (e, ui) =>
                    @annotate ui.item, styleClass: "acknowledged"
                    @_logger.info "autocomplete.select", e.target, ui
            .focus(200)
            .blur (e, ui) =>
                @_dialogCloseTimeout = setTimeout ( => @close()), 200
            if not @entityEnhancements.length and not @isAnnotated()
                setTimeout =>
                    label = @element.html()
                    @searchbox.val label
                    @searchbox.autocomplete "search", label
                , 300
            @_logger.info "show searchbox"

        # add a textEnhancement that gets shown when the dialog is rendered
        addTextEnhancement: (textEnh) ->
            @options.textEnhancements = @options.textEnhancements or []
            @options.textEnhancements.push textEnh
            @textEnhancements = @options.textEnhancements

    window.ANTT = ANTT
) jQuery
