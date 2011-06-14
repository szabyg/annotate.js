(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  (function(jQuery) {
    var Suggestion, deleteEnhancements, getEntityAnnotations, getOrCreateDomElement, getRightLabel, getTextAnnotations, ns, processSuggestion;
    ns = {
      rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      enhancer: 'http://fise.iks-project.eu/ontology/',
      dc: 'http://purl.org/dc/terms/',
      rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
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
    deleteEnhancements = function(oldDocUri) {};
    getRightLabel = function(entity) {
      var label, labelMap, userLang, _i, _len, _ref;
      ({
        getLang: function(label) {
          return label["xml:lang"];
        }
      });
      labelMap = {};
      _ref = _(entity["" + ns.rdfs + "label"]).flatten();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        label = _ref[_i];
        labelMap[label["xml:lang"] || "_"] = label.value;
      }
      userLang = window.navigator.language.split("-")[0];
      if (labelMap[userLang]) {
        return labelMap[userLang].value;
      } else {
        return labelMap["_"];
      }
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
      var el, sType;
      el = $(getOrCreateDomElement(parentEl[0], suggestion.getSelectedText(), {
        createElement: 'span'
      }));
      sType = suggestion.getType();
      el.addClass('entity').addClass(sType.substring(sType.lastIndexOf("/") + 1));
      el.addClass("withSuggestions");
      return el.annotationSelector({
        suggestion: suggestion
      });
    };
    jQuery.fn.analyze = function() {
      var analyzedNode, oldDocUri;
      analyzedNode = this;
      oldDocUri = this.data("analizedDocUri");
      if (oldDocUri) {
        deleteEnhancements(oldDocUri);
      }
      return VIE2.connectors['stanbol'].analyze(this, {
        success: __bind(function(rdf) {
          var docUri, rdfJson, textAnnotations;
          rdfJson = rdf.databank.dump();
          VIE.EntityManager.getByRDFJSON(rdfJson);
          textAnnotations = getTextAnnotations();
          docUri = _(textAnnotations).first().get("<" + ns.enhancer + "extracted-from>");
          this.data("analizedDocUri", docUri);
          return jQuery.each(textAnnotations, function() {
            var s;
            s = new Suggestion(this);
            console.info(s._enhancement, 'selectedText', s.getSelectedText(), 'type', s.getType(), 'EntityEnhancements', s.getEntityEnhancements());
            return processSuggestion(s, analyzedNode);
          });
        }, this)
      });
    };
    jQuery.widget('IKS.annotationSelector', {
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
          this.entityEnhancements = this.suggestion.getEntityEnhancements();
          console.info(this.entityEnhancements);
          if (this.entityEnhancements.length > 0) {
            return this._createMenu();
          } else {
            return this._showSearchbox();
          }
        }, this));
      },
      _createMenu: function() {
        var ul;
        ul = $('<ul></ul>').appendTo($("body")[0]);
        this._renderMenu(ul, this.entityEnhancements);
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
      },
      _showSearchbox: function() {
        var searchEntryField;
        searchEntryField = $('<span style="background: fff;"><label for="search"></label><input class="search"></span>').appendTo($("body")[0]);
        searchEntryField.position({
          of: this.element,
          my: "left top",
          at: "left bottom",
          collision: "none"
        });
        $('.search', searchEntryField).autocomplete({
          source: function(req, resp) {
            console.info("req:", req);
            return VIE2.connectors['stanbol'].findEntity("" + req.term + (req.term.length > 3 ? '*' : void 0), function(entityList) {
              var entity, i, res;
              console.info("resp:", _(entityList).map(function(ent) {
                return ent.id;
              }));
              res = (function() {
                var _results;
                _results = [];
                for (i in entityList) {
                  entity = entityList[i];
                  _results.push({
                    key: entity.id,
                    label: getRightLabel(entity)
                  });
                }
                return _results;
              })();
              return resp(res);
            });
          }
        });
        return console.info("show searchbox");
      }
    });
    return jQuery.widget('IKS.manualAnnotationLookup', {
      options: {
        suggestion: null
      }
    });
  })(jQuery);
}).call(this);
