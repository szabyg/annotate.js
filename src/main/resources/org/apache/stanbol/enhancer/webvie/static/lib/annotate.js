(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  (function(jQuery) {
    var ANTT, ns;
    ns = {
      rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      enhancer: 'http://fise.iks-project.eu/ontology/',
      dc: 'http://purl.org/dc/terms/',
      rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
    };
    ANTT = ANTT || {};
    ANTT.getTextAnnotations = function(enhRdf) {
      var res;
      res = _(enhRdf).map(function(obj, key) {
        obj.id = key;
        return obj;
      }).filter(function(e) {
        return e["" + ns.rdf + "type"].map(function(x) {
          return x.value;
        }).indexOf("" + ns.enhancer + "TextAnnotation") !== -1;
      });
      res = _(res).sortBy(function(e) {
        var conf;
        if (e["" + ns.enhancer + "confidence"]) {
          conf = Number(e["" + ns.enhancer + "confidence"][0].value);
        }
        return -1 * conf;
      });
      return _(res).map(function(s) {
        return new ANTT.Suggestion(s, enhRdf);
      });
    };
    ANTT.getEntityAnnotations = function(enhRdf) {
      return _(enhRdf).map(function(obj, key) {
        obj.id = key;
        return obj;
      }).filter(function(e) {
        return e["" + ns.rdf + "type"].map(function(x) {
          return x.value;
        }).indexOf("" + ns.enhancer + "EntityAnnotation") !== -1;
      });
    };
    ANTT.getRightLabel = function(entity) {
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
    ANTT.Suggestion = function(enhancement, enhRdf) {
      this._enhancement = enhancement;
      this.enhRdf = enhRdf;
      return this.id = this._enhancement.id;
    };
    ANTT.Suggestion.prototype = {
      getSelectedText: function() {
        return this._vals("" + ns.enhancer + "selected-text")[0];
      },
      getConfidence: function() {
        return this._vals("" + ns.enhancer + "confidence")[0];
      },
      getEntityEnhancements: function() {
        var rawList;
        rawList = _(ANTT.getEntityAnnotations(this.enhRdf)).filter(__bind(function(ann) {
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
          return new ANTT.EntityEnhancement(ee);
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
    ANTT.EntityEnhancement = function(ee) {
      return $.extend(this, ee);
    };
    ANTT.EntityEnhancement.prototype = {
      getLabel: function() {
        return this._vals("" + ns.enhancer + "entity-label")[0];
      },
      getUri: function() {
        return this._vals("" + ns.enhancer + "entity-reference")[0];
      },
      getTypes: function() {
        return this._vals("" + ns.enhancer + "entity-type");
      },
      getConfidence: function() {
        return Number(this._vals("" + ns.enhancer + "confidence")[0]);
      },
      _vals: function(key) {
        return _(this[key]).map(function(x) {
          return x.value;
        });
      }
    };
    ANTT.getOrCreateDomElement = function(element, text, options) {
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
    ANTT.processSuggestion = function(suggestion, parentEl) {
      var el, sType;
      el = $(ANTT.getOrCreateDomElement(parentEl[0], suggestion.getSelectedText(), {
        createElement: 'span',
        createMode: 'existing',
        context: suggestion.getContext(),
        start: suggestion.getStart(),
        end: suggestion.getEnd()
      }));
      sType = suggestion.getType();
      el.addClass('entity').addClass(ANTT.uriSuffix(sType));
      el.addClass("withSuggestions");
      return el.annotationSelector().annotationSelector('addSuggestion', suggestion);
    };
    ANTT.uriSuffix = function(uri) {
      return uri.substring(uri.lastIndexOf("/") + 1);
    };
    ANTT.cloneCopyEvent = function(src, dest) {
      var curData, events, internalKey, oldData;
      if (dest.nodeType !== 1 || !jQuery.hasData(src)) {
        return;
      }
      internalKey = $.expando;
      oldData = $.data(src);
      curData = $.data(dest, oldData);
      if (oldData = oldData[internalKey]) {
        events = oldData.events;
        curData = curData[internalKey] = jQuery.extend({}, oldData);
        if (events) {
          delete curData.handle;
          curData.events = {};
          for ( var type in events ) {
                    for ( var i = 0, l = events[ type ].length; i < l; i++ ) {
                        jQuery.event.add( dest, type + ( events[ type ][ i ].namespace ? "." : "" ) + events[ type ][ i ].namespace, events[ type ][ i ], events[ type ][ i ].data );
                    }
                };
        }
        return null;
      }
    };
    ANTT.analyze = jQuery.fn.analyze = function() {
      var analyzedNode;
      analyzedNode = this;
      return VIE2.connectors['stanbol'].analyze(this, {
        success: __bind(function(rdf) {
          var rdfJson, textAnnotations;
          rdfJson = rdf.databank.dump();
          textAnnotations = ANTT.getTextAnnotations(rdfJson);
          return _(textAnnotations).each(function(s) {
            console.info(s._enhancement, 'confidence', s.getConfidence(), 'selectedText', s.getSelectedText(), 'type', s.getType(), 'EntityEnhancements', s.getEntityEnhancements());
            return ANTT.processSuggestion(s, analyzedNode);
          });
        }, this)
      });
    };
    ANTT.annotationSelector = jQuery.widget('IKS.annotationSelector', {
      options: {
        suggestion: null,
        ns: {
          dbpedia: "http://dbpedia.org/ontology/"
        },
        getTypes: function() {
          return [
            {
              uri: "" + this.ns.dbpedia + "Place",
              label: 'Place'
            }, {
              uri: "" + this.ns.dbpedia + "Person",
              label: 'Person'
            }, {
              uri: "" + this.ns.dbpedia + "Organisation",
              label: 'Organisation'
            }
          ];
        },
        getSources: function() {
          return [
            {
              uri: "http://dbpedia.org/resource/",
              label: "dbpedia"
            }, {
              uri: "http://sws.geonames.org/",
              label: "geonames"
            }
          ];
        }
      },
      _typeLabels: function(types) {
        var allKnownPrefixes, knownMapping, knownPrefixes;
        knownMapping = this.options.getTypes();
        allKnownPrefixes = _(knownMapping).map(function(x) {
          return x.uri;
        });
        knownPrefixes = _.intersect(allKnownPrefixes, types);
        return _(knownPrefixes).map(__bind(function(key) {
          var foundPrefix;
          foundPrefix = _(knownMapping).detect(function(x) {
            return x.uri === key;
          });
          return foundPrefix.label;
        }, this));
      },
      _sourceLabel: function(src) {
        var sourceObj, sources;
        sources = this.options.getSources();
        sourceObj = _(sources).detect(function(s) {
          return src.indexOf(s.uri) !== -1;
        });
        if (sourceObj) {
          return sourceObj.label;
        } else {
          return src.split("/")[2];
        }
      },
      _create: function() {
        return this.element.click(__bind(function() {
          this._createDialog();
          this.entityEnhancements = this.suggestion.getEntityEnhancements();
          console.info(this.entityEnhancements);
          this._createSearchbox();
          if (this.entityEnhancements.length > 0) {
            if (this.menu === void 0) {
              return this._createMenu();
            }
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
        }, this)).bind('dialogblur', __bind(function(event) {
          console.info('dialog dialogblur');
          return this.close(event);
        }, this)).bind('blur', __bind(function(event) {
          console.info('dialog blur');
          return this.close(event);
        }, this)).appendTo($("body")[0]);
        dialogEl.dialog({
          width: 400,
          title: label,
          close: __bind(function(event, ui) {
            return this.close(event);
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
        this.dialog.element.focus(100);
        window.d = this.dialog;
        this._updateTitle();
        return this._setButtons();
      },
      _setButtons: function() {
        return this.dialog.element.dialog('option', 'buttons', {
          rem: {
            text: this.isAnnotated() ? 'Remove' : 'Decline',
            click: __bind(function() {
              return this.remove();
            }, this)
          },
          Cancel: __bind(function() {
            return this.close();
          }, this)
        });
      },
      remove: function() {
        var el;
        el = this.element.parent();
        console.info(el.html());
        this.element.replaceWith(document.createTextNode(this.element.text()));
        console.info(el.html());
        return this.close();
      },
      isAnnotated: function() {
        if (this.element.attr('about')) {
          return true;
        } else {
          return false;
        }
      },
      annotate: function(entityEnhancement, styleClass) {
        var entityClass, entityHtml, entityType, entityUri, newElement;
        entityUri = entityEnhancement.getUri();
        entityType = this.suggestion.getType();
        entityHtml = this.element.html();
        entityClass = this.element.attr('class');
        newElement = $("<a href='" + entityUri + "'                 about='" + entityUri + "'                 typeof='" + entityType + "'                class='" + entityClass + "'>" + entityHtml + "</a>");
        ANTT.cloneCopyEvent(this.element[0], newElement[0]);
        this.linkedEntity = {
          uri: entityUri,
          type: entityType
        };
        this.element.replaceWith(newElement);
        this.element = newElement.addClass(styleClass);
        console.info("created enhancement in", this.element);
        return this._updateTitle();
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
      _updateTitle: function() {
        var title;
        if (this.isAnnotated()) {
          title = "" + (this.element.text()) + " <small>at " + (this._sourceLabel(this.linkedEntity.uri)) + "</small>";
        } else {
          title = this.element.text();
        }
        return this.dialog.element.dialog('option', 'title', title);
      },
      _createMenu: function() {
        var ul;
        ul = $('<ul></ul>').appendTo(this.dialog.element);
        this._renderMenu(ul, this.entityEnhancements);
        this.menu = ul.menu({
          select: __bind(function(event, ui) {
            console.info(ui.item);
            this.annotate(ui.item.data('enhancement'), 'acknowledged');
            return this.close(event);
          }, this),
          blur: function(event, ui) {
            return console.info('menu.blur()', ui.item);
          }
        }).bind('blur', function(event, ui) {
          return console.info('menu blur', ui);
        }).bind('menublur', function(event, ui) {
          return console.info('menu menublur', ui.item);
        }).focus(150).data('menu');
        console.info("createMenu");
        return console.info(this.menu.element);
      },
      _renderMenu: function(ul, entityEnhancements) {
        var enhancement, _i, _len;
        entityEnhancements = _(entityEnhancements).sortBy(function(ee) {
          return -1 * ee.getConfidence();
        });
        for (_i = 0, _len = entityEnhancements.length; _i < _len; _i++) {
          enhancement = entityEnhancements[_i];
          this._renderItem(ul, enhancement);
        }
        return console.info('render', entityEnhancements);
      },
      _renderItem: function(ul, enhancement) {
        var label, source, type;
        console.info('enhancement:', enhancement, 'conf:', enhancement.getConfidence());
        label = enhancement.getLabel();
        type = this._typeLabels(enhancement.getTypes());
        source = this._sourceLabel(enhancement.getUri());
        return $("<li><a href='#'>" + label + " <small>(" + type + " from " + source + ")</small></a></li>").data('enhancement', enhancement).appendTo(ul);
      },
      _removeAnnotation: function() {
        this.element.removeAttr('about');
        return this.element.removeAttr('typeof');
      },
      _createSearchbox: function() {
        var searchEntryField;
        searchEntryField = $('<span style="background: fff;"><label for="search"></label><input class="search"></span>').appendTo(this.dialog.element);
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
                    label: ANTT.getRightLabel(entity),
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
        }).focus(200);
        return console.info("show searchbox");
      },
      addSuggestion: function(suggestion) {
        this.options.suggestion = suggestion;
        return this.suggestion = this.options.suggestion;
      }
    });
    return window.ANTT = ANTT;
  })(jQuery);
}).call(this);
