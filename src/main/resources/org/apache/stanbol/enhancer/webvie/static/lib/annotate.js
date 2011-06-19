(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  (function(jQuery) {
    var EntityEnhancement, Suggestion, getEntityAnnotations, getOrCreateDomElement, getRightLabel, getTextAnnotations, ns, processSuggestion;
    ns = {
      rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      enhancer: 'http://fise.iks-project.eu/ontology/',
      dc: 'http://purl.org/dc/terms/',
      rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
    };
    getTextAnnotations = function(enhRdf) {
      var res;
      res = _(enhRdf).map(function(obj, key) {
        obj.id = key;
        return obj;
      }).filter(function(e) {
        return e["" + ns.rdf + "type"].map(function(x) {
          return x.value;
        }).indexOf("" + ns.enhancer + "TextAnnotation") !== -1;
      });
      return _(res).sortBy(function(e) {
        var conf;
        if (e["" + ns.enhancer + "confidence"]) {
          conf = Number(e["" + ns.enhancer + "confidence"][0].value);
        }
        return -1 * conf;
      });
    };
    getEntityAnnotations = function(enhRdf) {
      return _(enhRdf).map(function(obj, key) {
        obj.id = key;
        return obj;
      }).filter(function(e) {
        return e["" + ns.rdf + "type"].map(function(x) {
          return x.value;
        }).indexOf("" + ns.enhancer + "EntityAnnotation") !== -1;
      });
    };
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
    Suggestion = function(enhancement, enhRdf) {
      this._enhancement = enhancement;
      this.enhRdf = enhRdf;
      return this.id = this._enhancement.id;
    };
    Suggestion.prototype = {
      getSelectedText: function() {
        return this._vals("" + ns.enhancer + "selected-text")[0];
      },
      getConfidence: function() {
        return this._vals("" + ns.enhancer + "confidence")[0];
      },
      getEntityEnhancements: function() {
        var rawList;
        rawList = _(getEntityAnnotations(this.enhRdf)).filter(__bind(function(ann) {
          var relations;
          relations = _(ann["" + ns.dc + "relation"]).map(function(e) {
            return e.value;
          });
          if ((relations.indexOf(this._enhancement.id)) !== -1) {
            return true;
          } else {
            return false;
          }
        }, this));
        return _(rawList).map(function(ee) {
          return new EntityEnhancement(ee);
        });
      },
      getType: function() {
        return this._vals("" + ns.dc + "type")[0];
      },
      getContext: function() {
        return this._vals("" + ns.enhancer + "selection-context")[0];
      },
      getStart: function() {
        return Number(this._vals("" + ns.enhancer + "start")[0]);
      },
      getEnd: function() {
        return Number(this._vals("" + ns.enhancer + "end")[0]);
      },
      _vals: function(key) {
        return _(this._enhancement[key]).map(function(x) {
          return x.value;
        });
      }
    };
    EntityEnhancement = function(ee) {
      return $.extend(this, ee);
    };
    EntityEnhancement.prototype = {
      getLabel: function() {
        return this._vals("" + ns.enhancer + "entity-label")[0];
      },
      getUri: function() {
        return this._vals("" + ns.enhancer + "entity-reference")[0];
      },
      _vals: function(key) {
        return _(this[key]).map(function(x) {
          return x.value;
        });
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
      var analyzedNode;
      analyzedNode = this;
      return VIE2.connectors['stanbol'].analyze(this, {
        success: __bind(function(rdf) {
          var rdfJson, textAnnotations;
          rdfJson = rdf.databank.dump();
          textAnnotations = getTextAnnotations(rdfJson);
          return jQuery.each(textAnnotations, function() {
            var s;
            s = new Suggestion(this, rdfJson);
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
      _create: function() {
        return this.element.click(__bind(function() {
          this._createDialog();
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
      _createDialog: function() {
        var dialogEl, label;
        label = this.element.text();
        dialogEl = $("<div>").attr("tabIndex", -1).addClass().keydown(__bind(function(event) {
          if (!event.isDefaultPrevented() && event.keyCode && event.keyCode === $.ui.keyCode.ESCAPE) {
            console.info("dialogEl ESCAPE key event -> close");
            this.close(event);
            return event.preventDefault();
          }
        }, this)).appendTo($("body")[0]);
        dialogEl.dialog({
          title: label,
          close: __bind(function(event, ui) {
            return this.close();
          }, this)
        });
        this.dialog = dialogEl.data('dialog');
        console.info(this.dialog);
        this.dialog.uiDialog.position({
          of: this.element,
          my: "left top",
          at: "left bottom",
          collision: "none"
        });
        return this.dialog.element.focus(200);
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
      close: function(event) {
        if (this.menu) {
          this.menu.destroy();
          this.menu.element.remove();
          delete this.menu;
        }
        this.dialog.destroy();
        this.dialog.element.remove();
        this.dialog.uiDialogTitlebar.remove();
        return delete this.dialog;
      },
      _createMenu: function() {
        var ul;
        ul = $('<ul></ul>').appendTo(this.dialog.element);
        this._renderMenu(ul, this.entityEnhancements);
        this.menu = ul.menu({
          select: __bind(function(event, ui) {
            console.info(ui.item);
            this.annotate(ui.item.data('enhancement'), 'acknowledged');
            return this.close();
          }, this),
          blur: function(event, ui) {
            console.info('blur', ui.item);
            return ui.item.parent().menu('destroy').remove();
          }
        }).focus().data('menu');
        console.info("createMenu");
        return console.info(this.menu.element);
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
        label = enhancement.getLabel();
        return $("<li><a href='#'>" + label + "</a></li>").data('enhancement', enhancement).appendTo(ul);
      },
      _createSearchbox: function() {
        var searchEntryField;
        searchEntryField = $('<span style="background: fff;"><label for="search"></label><input class="search"></span>').appendTo(this.dialog.element);
        searchEntryField;
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
            return console.info(e.target);
          }, this)
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
