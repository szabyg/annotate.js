(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  (function(jQuery) {
    var Suggestion, getEntityAnnotations, getOrCreateDomElement, getTextAnnotations, ns, processSuggestion;
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
    getEntityAnnotations = function() {
      return VIE.EntityManager.entities.filter(function(e) {
        return e.attributes["<" + ns.rdf + "type>"].indexOf("" + ns.enhancer + "EntityAnnotation") !== -1;
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
        return _(getEntityAnnotations()).filter(__bind(function(ann) {
          if (_(ann.attributes["<" + ns.dc + "relation>"]).flatten().indexOf(this._enhancement.id) !== -1) {
            return true;
          } else {
            return false;
          }
        }, this));
      },
      getType: function() {
        return this._enhancement.toJSON()["<" + ns.dc + "type>"];
      },
      toJSON: function() {
        return this._enhancement.toJSON();
      }
    };
    getOrCreateDomElement = function(element, text, options) {
      var domEl, len, newElement, pos;
      if (options == null) {
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
      var el, sType, w;
      el = $(getOrCreateDomElement(parentEl[0], suggestion.getSelectedText(), {
        createElement: 'span'
      }));
      sType = suggestion.getType();
      el.addClass('entity').addClass(sType.substring(sType.lastIndexOf("/") + 1));
      if (suggestion.getEntityEnhancements().length > 0) {
        el.addClass("withSuggestions");
      }
      return w = el.annotationSelector({
        suggestion: suggestion
      });
    };
    jQuery.fn.analyze = function() {
      var analyzedNode;
      analyzedNode = this;
      return VIE2.connectors['stanbol'].analyze(this, {
        success: function(rdf) {
          var rdfJson, textAnnotations;
          rdfJson = rdf.databank.dump();
          VIE.EntityManager.getByRDFJSON(rdfJson);
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
    return jQuery.widget('IKS.annotationSelector', {
      options: {
        suggestion: null
      },
      annotate: function(entityEnhancement, styleClass) {
        this.element.attr('about', entityEnhancement.get("<" + ns.enhancer + "entity-reference>"));
        this.element.addClass(styleClass);
        return console.info("created enhancement in", this.element);
      },
      _renderMenu: function(ul, entityEnhancements) {
        var enhancement, _i, _len;
        for (_i = 0, _len = entityEnhancements.length; _i < _len; _i++) {
          enhancement = entityEnhancements[_i];
          this._renderItem(ul, enhancement);
        }
        return console.info('render', entityEnhancements);
      },
      _renderItem: function(ul, enhancement) {
        var label;
        label = enhancement.get("<" + ns.enhancer + "entity-label>");
        return $("<li><a href='#'>" + label + "</a></li>").data('enhancement', enhancement).appendTo(ul);
      },
      _create: function() {
        this.suggestion = this.options.suggestion;
        return this.element.click(__bind(function() {
          var ul;
          console.info(this.suggestion.getEntityEnhancements());
          ul = $('<ul></ul>').appendTo($("body")[0]);
          this._renderMenu(ul, this.suggestion.getEntityEnhancements());
          this.menu = ul.menu({
            select: __bind(function(event, ui) {
              console.info(ui.item);
              this.annotate(ui.item.data('enhancement'), 'acknowledged');
              return ui.item.parent().menu('destroy').html('');
            }, this),
            blur: function(event, ui) {
              console.info('blur', ui.item);
              return ui.item.parent().menu('destroy').html('');
            }
          }).bind('menublur', function(event, ui) {
            console.info('menublur', ui.item);
            return ui.item.parent().menu('destroy').html('');
          }).data('menu');
          this.menu.element.position({
            of: this.element,
            my: "left top",
            at: "left bottom",
            collision: "none"
          });
          return console.info(this.menu.element);
        }, this));
      }
    });
  })(jQuery);
}).call(this);
