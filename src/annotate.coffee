###   Annotate - a text enhancement interaction jQuery UI widget
#     (c) 2011 Szaby Gruenwald, IKS Consortium
#     Annotate may be freely distributed under the MIT license
###
# define namespaces
ns =
    rdf:      'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
    enhancer: 'http://fise.iks-project.eu/ontology/'
    dcterms:  'http://purl.org/dc/terms/'
    rdfs:     'http://www.w3.org/2000/01/rdf-schema#'
    skos:     'http://www.w3.org/2004/02/skos/core#'

root = this
jQuery = root.jQuery
Backbone = root.Backbone
_ = root._
VIE = root.VIE

vie = new VIE()
vie.use(new vie.StanbolService({
    url : "http://dev.iks-project.eu:8080",
    proxyDisabled: true
}));
vie.namespaces.add "skos", ns.skos

# In Internet Explorer String.trim is not defined but we're going to use it.
String.prototype.trim ?= ->
    @replace /^\s+|\s+$/g, ''

# calling the get with a scope and callback will call cb(entity) with the scope as soon it's available.'
class EntityCache
    constructor: (opts) ->
        @vie = opts.vie
        @logger = opts.logger
    _entities: -> window.entityCache ?= {}
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
            @vie.load({entity: uri}).using('stanbol').execute().success (entityArr) =>
                _.defer =>
                    cacheEntry = @_entities()[uri]
                    entity = _.detect entityArr, (e) ->
                        true if e.getSubject() is "<#{uri}>"
                    if entity
                        cacheEntry.entity = entity
                        cacheEntry.status = "done"
                        $(cacheEntry).trigger "done", entity
                    else
                        @logger.warn "couldn''t load #{uri}", entityArr
                        cacheEntry.status = "not found"
            .fail (e) =>
                _.defer =>
                    @logger.error "couldn't load #{uri}"
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

# Give back the last part of a uri for fallback label creation
uriSuffix = (uri) ->
    res = uri.substring uri.lastIndexOf("#") + 1
    res.substring res.lastIndexOf("/") + 1

######################################################
# Annotate widget
# makes a content dom element interactively annotatable
######################################################
jQuery.widget 'IKS.annotate',
    __widgetName: "IKS.annotate"
    options:
        # VIE instance to use for (backend) enhancement
        vie: vie
        vieServices: ["stanbol"]
        # Do analyze on instantiation
        autoAnalyze: false
        # Keeps continouosly checking in the background, while typing
        continuousChecking: false
        # Wait for some time (in ms) for the user not typing, before it starts analyzing.
        throttleDistance: 5000
        # Tooltip can be disabled
        showTooltip: true
        # Debug can be enabled
        debug: false
        # Define Entity properties for finding depiction
        depictionProperties: [
            "foaf:depiction"
            "schema:thumbnail"
        ]
        # Lookup for a label will inspect these properties of an entity
        labelProperties: [
            "rdfs:label"
            "skos:prefLabel"
            "schema:name"
            "foaf:name"
        ]
        # Lookup for a description will inspect these properties of an entity
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
                property: "dcterms:subject"
                makeLabel: (propertyValueArr) ->
                    labels = _(propertyValueArr).map (termUri) ->
                        # extract the last part of the uri
                        termUri
                        .replace(/<.*[\/#](.*)>/, "$1")
                        .replace /_/g, "&nbsp;"
                    "Subject(s): #{labels.join ', '}."
        ]
        # If label and description is not available in the user's language 
        # look for a fallback.
        fallbackLanguage: "en"
        # namespaces necessary for the widget configuration
        ns:
            dbpedia:  "http://dbpedia.org/ontology/"
            skos:     "http://www.w3.org/2004/02/skos/core#"
        # List of enhancement types to filter for
        typeFilter: null
        annotationInteractionWidget: "annotationInteraction"
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
    # widget specific constructor
    _create: ->
        widget = @
        # logger can be turned on and off. It will show the real caller line in the log
        @_logger = if @options.debug then console else 
            info: ->
            warn: ->
            error: ->
            log: ->
        # widget.entityCache.get(uri, cb) will get and cache the entity from an entityhub
        @entityCache = new EntityCache 
            vie: @options.vie
            logger: @_logger
        if @options.autoAnalyze
            @enable()
        unless jQuery().tooltip
            @options.showTooltip = false
            @_logger.warn "the used jQuery UI doesn't support tooltips, disabling."
        @_initExistingAnnotations()
    _destroy: ->
        do @disable
        $( ':iks-annotationselector', @element ).each () ->
            $(@).annotationSelector 'destroy' if $(@).data().annotationSelector
        @_destroyExistingAnnotationInteractionWidgets()

    # analyze the widget element and show text enhancements
    enable: ->
      if @options.continuousChecking
        checkerFn = delayThrottle =>
          @_checkForChanges()
        , @options.throttleDistance

        $(@element).bind 'keyup', =>
          checkerFn()
      @_checkForChanges()


    _checkForChanges: ->
      for el in @_findElementsToAnalyze()
        hash = @_elementHash el
        unless jQuery(el).data('hash')
          console.info el, "wasn't analized yet."
          @_analyze el
        if jQuery(el).data('hash') and jQuery(el).data('hash') isnt hash
          console.info el, 'changed, try to get annotations for it.'
          @_analyze el

    _elementHash: (el) ->
      jQuery(el).text().hashCode()

    _findElementsToAnalyze: ->
      @_listNonblockElements @element

    _analyze: (el) ->
        hash = @_elementHash el
        # the analyzedDocUri makes the connection between a document state and
        # the annotations to it. We have to clean up the annotations to any
        # old document state

        @options.vie.analyze( element: jQuery el ).using(@options.vieServices)
        .execute()
        .success (enhancements) =>
          if @_elementHash(el) is hash
            console.info 'applying suggestions to', el, enhancements
            @_applyEnhancements el, enhancements
            jQuery(el).data 'hash', hash
          else
            console.info el, 'changed in the meantime.'
          @_trigger "success", true
        .fail (xhr) =>
          @_trigger 'error', xhr
          @_logger.error "analyze failed", xhr.responseText, xhr

    _applyEnhancements: (el, enhancements) ->
        _.defer =>
          # Link TextAnnotation entities to EntityAnnotations
          entityAnnotations = Stanbol.getEntityAnnotations(enhancements)
          for entAnn in entityAnnotations
              textAnns = entAnn.get "dcterms:relation"
              unless textAnns
                  @_logger.error "For #{entAnn.getSubject()} dcterms:relation is not set! This makes this EntityAnnotation unusable!", entAnn
                  continue
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
              @_processTextEnhancement s, el
    # Remove all not accepted text enhancement widgets
    disable: ->
        $( ':IKS-annotationSelector', @element ).each () ->
            $(@).annotationSelector 'disable' if $(@).data().annotationSelector
    _initExistingAnnotations: ->
        @existingAnnotations = jQuery "a[resource]", @element
        @_logger.info @existingAnnotations
        @existingAnnotations[@options.annotationInteractionWidget] @options
    _destroyExistingAnnotationInteractionWidgets: ->
        @existingAnnotations[@options.annotationInteractionWidget] "destroy"
        @existingAnnotations = []
    # accept the best (first) suggestion for all text enhancement.
    acceptAll: (reportCallback) ->
        report = {updated: [], accepted: 0}
        $( ':IKS-annotationSelector', @element ).each () ->
            if $(@).data().annotationSelector
                res = $(@).annotationSelector 'acceptBestCandidate'
                if res
                    report.updated.push @
                    report.accepted++
        reportCallback report

    # Internal methods
    # Devide an element into smaller chunks that can be analyzed in smaller portions.
    _listNonblockElements: (el) ->
      # An element is devidable if the sum of all it's children's text is it's own text. Otherwise it has textnodes that are no dom tags.
      isDevidable = (el) =>
        sum = ""
        for child in jQuery(el).children()
          sum += jQuery(child).text().replace /\s\s*/g, ""
        jQuery(el).text().replace(/\s\s*/g, "") is sum

      res = jQuery []
      if isDevidable el
        jQuery(el).children().each (i, ch) =>
          res = res.add @_listNonblockElements(ch)
      else
        res = res.add jQuery el
      res


# processTextEnhancement deals with one TextEnhancement in an ancestor element of its occurrence
    _processTextEnhancement: (textEnh, parentEl) ->
        if not textEnh.getSelectedText()
            @_logger.warn "textEnh", textEnh, "doesn't have selected-text!"
            return
        el = $ @_getOrCreateDomElement parentEl, textEnh.getSelectedText(),
            createElement: 'span'
            createMode: 'existing'
            context: textEnh.getContext()
            start:   textEnh.getStart()
            end:     textEnh.getEnd()
        sType = textEnh.getType() or "Other"
        widget = @
        el.addClass('entity')
        for type in sType
            el.addClass uriSuffix(type).toLowerCase()
        if textEnh.getEntityEnhancements().length
            el.addClass "withSuggestions"
        for eEnh in textEnh.getEntityEnhancements()
            eEnhUri = eEnh.getUri()
            @entityCache.get eEnhUri, eEnh, (entity) =>
                if "<#{eEnhUri}>" is entity.getSubject()
                    @_logger.info "entity #{eEnhUri} is loaded:",
                        entity.as "JSON"
                else
                    widget._logger.info "forwarded entity for #{eEnhUri} loaded:", entity.getSubject()
        # Create widget to select from the suggested entities
        options = @options
        options.cache = @entityCache
        options.annotateElement = @element
        el.annotationSelector( options )
        .annotationSelector 'addTextEnhancement', textEnh

    _filterByType: (textAnnotations) ->
        return textAnnotations unless @options.typeFilter
        _.filter textAnnotations, (ta) =>
            return yes if @options.typeFilter in ta.getType()
            for type in @options.typeFilter
                return yes if type in ta.getType()

    # get or create a dom element containing only the occurrence of the found entity
    _getOrCreateDomElement: (element, text, options = {}) ->
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
            @_logger.error "'#{text}' doesn't appear in the text block."
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
                @_logger.warn "dom element creation problem: #{textToCut} isnt #{text}"

# Similar to the Java String.hashCode() method, it calculates a hash value of the string.
String::hashCode = ->
  hash = 0
  return hash  if @length is 0
  i = 0
  while i < @length
    char = @charCodeAt(i)
    hash = ((hash << 5) - hash) + char
    hash = hash & hash
    i++
  hash

# For throttling keyup events, this method sets up an event handler function resFn that only triggers the callback function cb after
# being called the resFn at least once AND not being called for timout milliseconds.
delayThrottle = (cb, timeout) ->
  timeoutHandler = null
  resFn = ->
    if timeoutHandler
      clearTimeout(timeoutHandler)
    timeoutHandler = setTimeout ->
      timeoutHandler = null
      cb()
    , timeout