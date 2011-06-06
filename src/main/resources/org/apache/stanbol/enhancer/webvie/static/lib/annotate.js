(function() {
  (function(jQuery) {
    var Suggestion, getOrCreateDomElement, getTextAnnotations, ns, processSuggestion;
    ns = {
      rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      enhancer: 'http://fise.iks-project.eu/ontology/',
      dc: 'http://purl.org/dc/terms/'
    };
    getTextAnnotations = function() {
      return VIE.EntityManager.entities.filter(function(e) {
        return e.attributes["<" + ns.rdf + "type>"].indexOf("" + ns.enhancer + "TextAnnotation") !== -1;
      });
    };
    Suggestion = function(enhancement) {
      var id;
      this._enhancement = enhancement;
      return id = this._enhancement.id;
    };
    Suggestion.prototype = {
      getSelectedText: function() {
        return this._enhancement.toJSON()["<" + ns.enhancer + "selected-text>"];
      },
      getEntityEnhancements: function() {
        var entityUris;
        entityUris = this._enhancement.toJSON()["<" + ns.dc + "relation>"];
        return _([entityUris]).flatten().map(function(uri) {
          return VIE.EntityManager.getBySubject(uri);
        });
      },
      getType: function() {
        return this._enhancement.toJSON()["<" + ns.dc + "type>"];
      }
    };
    getOrCreateDomElement = function(element, text, options) {
      var domEl, len, newElement, pos;
      if (options === void 0) {
        options = {};
      }
      domEl = element;
      if (element.textContent.indexOf(text) === -1) {
        throw "'" + text + "' doesn't appear in the text block.";
        return $();
      }
      while (domEl.textContent.indexOf(text) !== -1 && domEl.nodeName !== '#text') {
        domEl = _(domEl.childNodes).detect(function(el) {
          return el.textContent.indexOf(text) !== -1;
        });
      }
      if (options.createMode === "existing" && domEl.parentElement.textContent === text) {
        return domEl.parentElement;
      } else {
        pos = domEl.nodeValue.indexOf(text);
        len = text.length;
        domEl.splitText(pos + len);
        newElement = document.createElement(options.createElement || 'span');
        newElement.innerHTML = text;
        domEl.parentElement.replaceChild(newElement, domEl.splitText(pos));
        return $(newElement);
      }
    };
    processSuggestion = function(suggestion, parentEl) {
      var el;
      el = getOrCreateDomElement(parentEl[0], suggestion.getSelectedText());
      return console.info(el);
    };
    return jQuery.fn.analyze = function() {
      var analyzedNode;
      analyzedNode = this;
      return VIE2.connectors['stanbol'].analyze(this, {
        success: function(rdf) {
          var rdfJson, textAnnotations;
          rdfJson = rdf.where("?s <" + ns.rdf + "type> <" + ns.enhancer + "Enhancement>").where('?s ?p ?o').dump();
          console.info(rdfJson);
          VIE.EntityManager.getByRDFJSON(rdfJson);
          console.info("VIE.EntityManager", VIE.EntityManager);
          textAnnotations = getTextAnnotations();
          return jQuery.each(textAnnotations, function() {
            var s;
            s = new Suggestion(this);
            console.info(s._enhancement, 'selectedText', s.getSelectedText(), 'type', s.getType(), 'EntityEnhancements', s.getEntityEnhancements());
            return processSuggestion(s, analyzedNode);
          });
        }
      });
    };
  })(jQuery);
}).call(this);
