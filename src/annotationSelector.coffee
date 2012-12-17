######################################################
# AnnotationSelector widget
# the annotationSelector makes an annotated word interactive
# This widget is instantiated by the IKS.annotate widget for the 
# text enhancements and RDFa annotated elements.
######################################################
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
        do @enableEditing
        @_logger = if @options.debug then console else 
            info: ->
            warn: ->
            error: ->
            log: ->
        if @isAnnotated()
            @_initTooltip()
            @linkedEntity =
                uri: @element.attr "resource"
                # type: @element.attr "typeof"
            @options.cache.get @linkedEntity.uri, @, (cachedEntity) =>
                navigatorLanguage = window.navigator.language || window.navigator.userLanguage
                userLang = navigatorLanguage.split("-")[0]
                @linkedEntity.label = VIE.Util.getPreferredLangForPreferredProperty cachedEntity, 
                  ["skos:prefLabel", "rdfs:label"], [userLang, "en"]
    enableEditing: ->
        @element.click (e) =>
            @_logger.log "click", e, e.isDefaultPrevented()
#                e.preventDefault()
            if @dialog or not @dialog # well, always..
                @_createDialog()
                setTimeout((=> @dialog.open()), 220)

                @entityEnhancements = @_getEntityEnhancements()

                @_createSearchbox()
                if @entityEnhancements.length > 0
                    @_createMenu()
            else @searchEntryField.find('.search').focus 100
    disableEditing: ->
        jQuery(@element).unbind 'click'
    _destroy: ->
        do @disableEditing
        if @menu
            @menu.destroy()
            @menu.element.remove()
            delete @menu
        if @dialog
            @dialog.destroy()
            @dialog.element.remove()
            @dialog.uiDialogTitlebar.remove()
            delete @dialog
        @_logger.info "destroy tooltip"
        @element.tooltip "destroy" if @element.data().tooltip

    # remove textEnhancement/annotation, replace the separate html
    # element with the plain text and close the dialog
    remove: (event) ->
        el = @element.parent()
        @_logger.info "destroy tooltip"
        @element.tooltip "destroy" if @element.data().tooltip
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
        else
            @disableEditing()

    # tells if this is an annotated dom element (not a highlighted textEnhancement only)
    isAnnotated: ->
        if @element.attr 'resource' then true else false

    # Place the annotation on the DOM element (resource and typeof attributes)
    annotate: (entityEnhancement, options) ->
        entityUri = entityEnhancement.getUri()
        entityType = entityEnhancement.getTextEnhancement().getType() or ""
        entityHtml = @element.html()
        # We ignore the old style classes
        # entityClass = @element.attr 'class'
        sType = entityEnhancement.getTextEnhancement().getType()
        sType = ["Other"] unless sType.length
        @element.attr 'xmlns:skos', ns.skos
        rel = options.rel or "skos:related"
        entityClass = 'entity ' + uriSuffix(sType[0]).toLowerCase()
        for type in ['Person', 'Place', 'Organisation']
          _(sType).each (t) ->
            if t.indexOf(type) isnt -1
              entityClass += " #{type}"
        newElement = $ "<a href='#{entityUri}'
            resource='#{entityUri}'
            rel='#{rel}'
            class='#{entityClass}'>#{entityHtml}</a>"
        @_cloneCopyEvent @element[0], newElement[0]
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
        ui =
            linkedEntity: @linkedEntity
            textEnhancement: entityEnhancement.getTextEnhancement()
            entityEnhancement: entityEnhancement
        @select ui
        @_initTooltip()
        jQuery(newElement).annotationSelector @options
        @dialog?.close()

    # triggering select event on the enclosing annotate element
    select: (ui) ->
        e = new jQuery.Event("select")
        e.ui = ui
        @_trigger 'select', e, ui
        jQuery(@options.annotateElement).trigger "annotateselect", ui

    # Accept first (best) entity enhancement (if any)
    acceptBestCandidate: ->
        eEnhancements = @_getEntityEnhancements()
        return unless eEnhancements.length
        return if @isAnnotated()
        @annotate eEnhancements[0], styleClass: "acknowledged"
        eEnhancements[0]

    # add a textEnhancement that gets shown when the dialog is rendered
    addTextEnhancement: (textEnh) ->
        @options.textEnhancements = @options.textEnhancements or []
        @options.textEnhancements.push textEnh
        @textEnhancements = @options.textEnhancements

    # closing the widget
    close: ->
        @dialog?.close?()
        jQuery(".ui-tooltip").remove()

    _initTooltip: ->
        widget = @
        if @options.showTooltip
            @_logger.info "init tooltip for", @element
            jQuery(@element).tooltip
                items: "[resource]"
                hide: 
                    effect: "hide"
                    delay: 50
                show:
                    effect: "show"
                    delay: 50
                content: (response) =>
                    uri = @element.attr "resource"
                    @_logger.info "tooltip uri:", uri
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
            if _.indexOf(_tempUris, uri) is -1
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
        knownPrefixes = _.intersection allKnownPrefixes, types
        _(knownPrefixes).map (key) =>
            foundPrefix = _(knownMapping).detect (x) -> x.uri is key
            foundPrefix.label

    # make a label for the entity source based on options.getSources()
    _sourceLabel: (src) ->
        @_logger.warn "No source" unless src
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
        jQuery(".annotateselector-dialog-content").dialog("destroy").remove()
        dialogEl = $("<div class='annotateselector-dialog-content'><span class='entity-link'></span></div>")
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
          dialogClass: 'annotation-selector-dialog'
          title: label
#          close: (event, ui) =>
#            @close(event)
          autoOpen: false
          open: (e, ui) ->
          position:
            of: @element
            my: "left top"
            at: "left bottom"
            collision: "flip"
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
                    @close()
            Cancel: =>
                @close()

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
        ul = $('<ul class="suggestion-menu"></ul>')
        .appendTo( @dialog.element )
        @_renderMenu ul, @entityEnhancements
        selectHandler = (event, ui) =>
            @_logger.info "selected menu item", ui.item
            @annotate ui.item.data('enhancement'), styleClass: 'acknowledged'
            @close(event)
        @menu = ul
        .menu({
            selected: selectHandler # jqueryui 1.8 needs .selected
            select: selectHandler # jqueryui 1.9 needs .select
            blur: (event, ui) =>
                @_logger.info 'menu.blur()', ui.item
            styleClass: 'suggestion-menu'
        })
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
        navigatorLanguage = window.navigator.language || window.navigator.userLanguage
        navigatorLanguage.split("-")[0]
    _getDepiction: (entity, picSize) ->
        preferredFields = @options.depictionProperties
        # field is the first property name with a value
        field = _(preferredFields).detect (field) ->
            true if entity.get field
        # fieldValue is an array of at least one value
        if field && fieldValue = _([entity.get field]).flatten()
            # 
            depictionUrl = _(fieldValue).detect (uri) ->
                uri = uri.getSubject?() or uri
                true if uri.indexOf("thumb") isnt -1
            .replace /[0-9]{2..3}px/, "#{picSize}px"
            depictionUrl

    _getLabel: (entity) ->
        preferredFields = @options.labelProperties
        preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
        VIE.Util.getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

    _getDescription: (entity) ->
        preferredFields = @options.descriptionProperties
        preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
        VIE.Util.getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

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
        item = $("<li#{active} entityuri='#{eEnhancement.getUri()}' resource='#{eEnhancement.getUri()}'><a>#{label} <small>(#{type} from #{source})</small></a></li>")
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
        .vieAutocomplete
          vie: @options.vie
          urifield: jQuery("#urifield")
          select: (e, ui) =>
            item = ui.item
            item.getUri = ->
              @key
            item._tEnh = sugg
            item.getTextEnhancement = -> @_tEnh
            item.getLabel = -> @label
            @annotate ui.item, styleClass: "acknowledged"
            @_logger.info "autocomplete.select", e.target, ui
        @searchEntryField
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

    _cloneCopyEvent: (src, dest) ->
        if jQuery().jquery.indexOf("1.6") is 0
            return @_cloneCopyEvent1_6 src, dest
        else 
            return @_cloneCopyEvent1_7 src, dest

    # jquery events cloning method
    _cloneCopyEvent1_6: (src, dest) ->
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

    _cloneCopyEvent1_7: (src, dest) ->
      return  if dest.nodeType isnt 1 or not jQuery.hasData(src)
      type = undefined
      i = undefined
      l = undefined
      oldData = jQuery._data(src)
      curData = jQuery._data(dest, oldData)
      events = oldData.events
      if events
        delete curData.handle

        curData.events = {}
        for type of events
          i = 0
          l = events[type].length

          while i < l
            jQuery.event.add dest, type + (if events[type][i].namespace then "." else "") + events[type][i].namespace, events[type][i], events[type][i].data
            i++
      curData.data = jQuery.extend({}, curData.data)  if curData.data
