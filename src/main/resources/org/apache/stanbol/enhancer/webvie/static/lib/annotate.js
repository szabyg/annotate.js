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
      var all;
      all = VIE.EntityManager.entities.filter(function(e) {
        return e.attributes["<" + ns.rdf + "type>"].indexOf("" + ns.enhancer + "TextAnnotation") !== -1;
      });
      return all = _(all).sortBy(function(e) {
        return -1 * Number(e.attributes["<" + ns.enhancer + "confidence>"]);
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
      getConfidence: function() {
        return this._enhancement.toJSON()["<" + ns.enhancer + "confidence>"];
      },
      getEntityEnhancements: function() {
        return _(getEntityAnnotations()).filter(__bind(function(ann) {
          if (_([ann.attributes["<" + ns.dc + "relation>"]]).flatten().indexOf(this._enhancement.id) !== -1) {
            return true;
          } else {
            return false;
          }
        }, this));
      },
      getType: function() {
        return this._enhancement.toJSON()["<" + ns.dc + "type>"];
      },
      getContext: function() {
        return this._enhancement.toJSON()["<" + ns.enhancer + "selection-context>"];
      },
      getStart: function() {
        return Number(this._enhancement.toJSON()["<" + ns.enhancer + "start>"]);
      },
      getEnd: function() {
        return Number(this._enhancement.toJSON()["<" + ns.enhancer + "end>"]);
      }
    };
    getOrCreateDomElement = function(element, text, options) {
      var domEl, len, newElement, pos, start, textContentOf;
      if (options == null) {
        options = {};
      }
      domEl = element;
      textContentOf = function(element) {
        return element.textContent.replace(/\n/g, " ");
      };
      if (textContentOf(element).indexOf(text) === -1) {
        throw "'" + text + "' doesn't appear in the text block.";
        return $();
      }
      start = options.start + textContentOf(element).indexOf(textContentOf(element).trim());
      pos = 0;
      while (textContentOf(domEl).indexOf(text) !== -1 && domEl.nodeName !== '#text') {
        domEl = _(domEl.childNodes).detect(function(el) {
          var p;
          p = textContentOf(el).lastIndexOf(text);
          if (p >= start - pos) {
            return true;
          } else {
            pos += textContentOf(el).length;
            return false;
          }
        });
      }
      if (options.createMode === "existing" && textContentOf(domEl.parentElement) === text) {
        return domEl.parentElement;
      } else {
        pos = start - pos;
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
        createElement: 'span',
        createMode: 'existing',
        context: suggestion.getContext(),
        start: suggestion.getStart(),
        end: suggestion.getEnd()
      }));
      sType = suggestion.getType();
      el.addClass('entity').addClass(sType.substring(sType.lastIndexOf("/") + 1));
      el.addClass("withSuggestions");
      return el.annotationSelector().annotationSelector('addSuggestion', suggestion);
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
            console.info(s._enhancement, 'confidence', s.getConfidence(), 'selectedText', s.getSelectedText(), 'type', s.getType(), 'EntityEnhancements', s.getEntityEnhancements());
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
        var entityClass, entityHtml, entityType, entityUri, newElement;
        entityUri = entityEnhancement.getUri();
        entityType = this.suggestion.getType();
        entityHtml = this.element.html();
        entityClass = this.element.attr('class');
        newElement = $("<a href='" + entityUri + "'                 about='" + entityUri + "'                 typeof='" + entityType + "'                class='" + entityClass + "'>" + entityHtml + "</a>");
        this.element.replaceWith(newElement);
        this.element = newElement.addClass(styleClass);
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
        $("<li><a href='#'>" + label + "</a></li>").data('enhancement', enhancement).appendTo(ul);
        return enhancement.getUri = function() {
          return this.get("<" + ns.enhancer + "entity-reference>");
        };
      },
      _create: function() {
        return this.element.click(__bind(function() {
          this.entityEnhancements = this.suggestion.getEntityEnhancements();
          console.info(this.entityEnhancements);
          if (this.entityEnhancements.length > 0) {
            if (this.menu === void 0) {
              return this._createMenu();
            }
          } else {
            return this._createSearchbox();
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
            ui.item.parent().menu('destroy').remove();
            return delete this.menu;
          }, this),
          blur: function(event, ui) {
            console.info('blur', ui.item);
            return ui.item.parent().menu('destroy').remove();
          }
        }).bind('menublur', function(event, ui) {
          console.info('menublur', ui.item);
          return ui.item.parent().menu('destroy').html('');
        }).focus().data('menu');
        console.info("createMenu");
        this.menu.element.position({
          of: this.element,
          my: "left top",
          at: "left bottom",
          collision: "none"
        });
        return console.info(this.menu.element);
      },
      _createSearchbox: function() {
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
                    label: getRightLabel(entity),
                    getUri: function() {
                      return this.key;
                    }
                  });
                }
                return _results;
              })();
              return resp(res);
            });
          },
          select: __bind(function(e, ui) {
            console.info("select event", e, ui);
            this.annotate(ui.item, "acknowledged");
            console.info(e.target);
            return $(e.target).remove();
          }, this)
        }).blur(function(e) {
          console.info("blur event", e, $(e.target));
          return $(e.target).autocomplete('option', 'destroy').parent().remove();
        }).trigger('focus');
        return console.info("show searchbox");
      },
      addSuggestion: function(suggestion) {
        this.options.suggestion = suggestion;
        return this.suggestion = this.options.suggestion;
      }
    });
    return jQuery.widget('IKS.manualAnnotationLookup', {
      options: {
        suggestion: null
      }
    });
  })(jQuery);
}).call(this);
