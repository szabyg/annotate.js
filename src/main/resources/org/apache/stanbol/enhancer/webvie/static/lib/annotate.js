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
        return new ANTT.TextEnhancement(s, enhRdf);
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
      var cleanLabel, label, labelMap, userLang, _i, _len, _ref;
      labelMap = {};
      _ref = _(entity["" + ns.rdfs + "label"]).flatten();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        label = _ref[_i];
        cleanLabel = label.value;
        if (cleanLabel.lastIndexOf("@" === cleanLabel.length - 3)) {
          cleanLabel = cleanLabel.substring(0, cleanLabel.length - 3);
        }
        labelMap[label["xml:lang"] || "_"] = cleanLabel;
      }
      userLang = window.navigator.language.split("-")[0];
      return labelMap[userLang] || labelMap["_"] || labelMap["en"];
    };
    ANTT.TextEnhancement = function(enhancement, enhRdf) {
      this._enhancement = enhancement;
      this._enhRdf = enhRdf;
      return this.id = this._enhancement.id;
    };
    ANTT.TextEnhancement.prototype = {
      getSelectedText: function() {
        return this._vals("" + ns.enhancer + "selected-text")[0];
      },
      getConfidence: function() {
        return this._vals("" + ns.enhancer + "confidence")[0];
      },
      getEntityEnhancements: function() {
        var rawList;
        rawList = _(ANTT.getEntityAnnotations(this._enhRdf)).filter(__bind(function(ann) {
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
        return _(rawList).map(__bind(function(ee) {
          return new ANTT.EntityEnhancement(ee, this);
        }, this));
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
      getOrigText: function() {
        var ciUri;
        ciUri = this._vals("" + ns.enhancer + "extracted-from")[0];
        return this._enhRdf[ciUri]["http://www.semanticdesktop.org/ontologies/2007/01/19/nie#plainTextContent"][0].value;
      },
      _vals: function(key) {
        return _(this._enhancement[key]).map(function(x) {
          return x.value;
        });
      }
    };
    ANTT.EntityEnhancement = function(ee, textEnh) {
      this._textEnhancement = textEnh;
      return $.extend(this, ee);
    };
    ANTT.EntityEnhancement.prototype = {
      getLabel: function() {
        return this._vals("" + ns.enhancer + "entity-label")[0];
      },
      getUri: function() {
        return this._vals("" + ns.enhancer + "entity-reference")[0];
      },
      getTextEnhancement: function() {
        return this._textEnhancement;
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
      var domEl, len, newElement, pos, start, textContentOf, textToCut;
      if (options == null) {
        options = {};
      }
      domEl = element;
      textContentOf = function(element) {
        return $(element).text().replace(/\n/g, " ");
      };
      if (textContentOf(element).indexOf(text) === -1) {
        throw "'" + text + "' doesn't appear in the text block.";
        return $();
      }
      start = options.start + textContentOf(element).indexOf(textContentOf(element).trim());
      start = ANTT.nearestPosition(textContentOf(element), text, start);
      if (!start) {
        debugger;
        start = options.start + textContentOf(element).indexOf(textContentOf(element).trim());
        start = ANTT.nearestPosition(textContentOf(element), text, start);
      }
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
      if (options.createMode === "existing" && textContentOf($(domEl).parent()) === text) {
        return $(domEl).parent()[0];
      } else {
        pos = start - pos;
        len = text.length;
        textToCut = textContentOf(domEl).substring(pos, pos + len);
        if (textToCut !== text) {
          debugger;
        }
        domEl.splitText(pos + len);
        newElement = document.createElement(options.createElement || 'span');
        newElement.innerHTML = text;
        $(domEl).parent()[0].replaceChild(newElement, domEl.splitText(pos));
        return $(newElement);
      }
    };
    ANTT.occurrences = function(str, s) {
      var last, next, res, _results;
      res = [];
      last = 0;
      _results = [];
      while (str.indexOf(s, last + 1) !== -1) {
        next = str.indexOf(s, last + 1);
        res.push(next);
        _results.push(last = next);
      }
      return _results;
    };
    ANTT.nearest = function(arr, nr) {
      return _(arr).sortedIndex(nr);
    };
    ANTT.nearestPosition = function(str, s, ind) {
      var arr, d0, d1, i0, i1;
      arr = this.occurrences(str, s);
      i1 = this.nearest(arr, ind);
      if (arr.length === 1) {
        return arr[0];
      } else if (i1 === arr.length) {
        return arr[i1 - 1];
      } else {
        i0 = i1 - 1;
        d0 = ind - arr[i0];
        d1 = arr[i1] - ind;
        if (d1 > d0) {
          return arr[i0];
        } else {
          return arr[i1];
        }
      }
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
    jQuery.widget('IKS.annotate', {
      options: {
        autoAnalyze: false
      },
      _create: function() {
        if (this.options.autoAnalyze) {
          return this.enable();
        }
      },
      enable: function() {
        var analyzedNode;
        analyzedNode = this.element;
        return VIE2.connectors['stanbol'].analyze(this.element, {
          success: __bind(function(rdf) {
            var rdfJson, textAnnotations;
            rdfJson = rdf.databank.dump();
            textAnnotations = ANTT.getTextAnnotations(rdfJson);
            textAnnotations = _(textAnnotations).filter(function(textEnh) {
              if (textEnh.getSelectedText && textEnh.getSelectedText()) {
                return true;
              } else {
                return false;
              }
            });
            return _(textAnnotations).each(__bind(function(s) {
              console.info(s._enhancement, 'confidence', s.getConfidence(), 'selectedText', s.getSelectedText(), 'type', s.getType(), 'EntityEnhancements', s.getEntityEnhancements());
              return this.processTextEnhancement(s, analyzedNode);
            }, this));
          }, this)
        });
      },
      disable: function() {
        return $(':IKS-annotationSelector', this.element).each(function() {
          return $(this).annotationSelector('disable');
        });
      },
      processTextEnhancement: function(textEnh, parentEl) {
        var el, sType;
        if (!textEnh.getSelectedText()) {
          console.warn("textEnh", textEnh, "doesn't have selected-text!");
          return;
        }
        el = $(ANTT.getOrCreateDomElement(parentEl[0], textEnh.getSelectedText(), {
          createElement: 'span',
          createMode: 'existing',
          context: textEnh.getContext(),
          start: textEnh.getStart(),
          end: textEnh.getEnd()
        }));
        sType = textEnh.getType();
        el.addClass('entity').addClass(ANTT.uriSuffix(sType));
        el.addClass("withSuggestions");
        return el.annotationSelector(this.options).annotationSelector('addTextEnhancement', textEnh);
      }
    });
    ANTT.annotationSelector = jQuery.widget('IKS.annotationSelector', {
      options: {
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
      _create: function() {
        return this.element.click(__bind(function() {
          var eEnhancements, enhancement, textEnh, _i, _j, _len, _len2, _ref, _ref2, _tempUris;
          this._createDialog();
          eEnhancements = [];
          _ref = this.textEnhancements;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            textEnh = _ref[_i];
            _ref2 = textEnh.getEntityEnhancements();
            for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
              enhancement = _ref2[_j];
              eEnhancements.push(enhancement);
            }
          }
          _tempUris = [];
          eEnhancements = _(eEnhancements).filter(function(eEnh) {
            var uri;
            uri = eEnh.getUri();
            if (_tempUris.indexOf(uri) === -1) {
              _tempUris.push(uri);
              return true;
            } else {
              return false;
            }
          });
          this.entityEnhancements = eEnhancements;
          console.info(this.entityEnhancements);
          this._createSearchbox();
          if (this.entityEnhancements.length > 0) {
            if (this.menu === void 0) {
              return this._createMenu();
            }
          }
        }, this));
      },
      _destroy: function() {
        console.info('destroy', this);
        return this.close();
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
      _createDialog: function() {
        var dialogEl, label;
        label = this.element.text();
        dialogEl = $("<div><span class='entity-link'></span></div>").attr("tabIndex", -1).addClass().keydown(__bind(function(event) {
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
        this.dialog.uiDialogTitlebar.hide();
        console.info("dialog widget:", this.dialog);
        this.dialog.uiDialog.position({
          of: this.element,
          my: "left top",
          at: "left bottom",
          collision: "none"
        });
        this.dialog.element.focus(100);
        window.d = this.dialog;
        this._insertLink();
        this._updateTitle();
        return this._setButtons();
      },
      _insertLink: function() {
        if (this.isAnnotated() && this.dialog) {
          return $("Annotated: <a href='" + this.linkedEntity.uri + "' target='_blank'>                " + this.linkedEntity.label + " @ " + (this._sourceLabel(this.linkedEntity.uri)) + "</a><br/>").appendTo($('.entity-link', this.dialog.element));
        }
      },
      _setButtons: function() {
        return this.dialog.element.dialog('option', 'buttons', {
          rem: {
            text: this.isAnnotated() ? 'Remove' : 'Decline',
            click: __bind(function(event) {
              return this.remove(event);
            }, this)
          },
          Cancel: __bind(function() {
            return this.close();
          }, this)
        });
      },
      remove: function(event) {
        var el;
        el = this.element.parent();
        if (!this.isAnnotated() && this.textEnhancements) {
          this._trigger('decline', event, {
            textEnhancements: this.textEnhancements
          });
        }
        this.destroy();
        if (this.element.qname().name !== '#text') {
          return this.element.replaceWith(document.createTextNode(this.element.text()));
        }
      },
      disable: function() {
        if (!this.isAnnotated() && this.element.qname().name !== '#text') {
          return this.element.replaceWith(document.createTextNode(this.element.text()));
        }
      },
      isAnnotated: function() {
        if (this.element.attr('about')) {
          return true;
        } else {
          return false;
        }
      },
      annotate: function(entityEnhancement, styleClass) {
        var entityClass, entityHtml, entityType, entityUri, newElement, sType;
        entityUri = entityEnhancement.getUri();
        entityType = entityEnhancement.getTextEnhancement().getType();
        entityHtml = this.element.html();
        sType = entityEnhancement.getTextEnhancement().getType();
        entityClass = 'entity ' + ANTT.uriSuffix(sType);
        newElement = $("<a href='" + entityUri + "'                about='" + entityUri + "'                typeof='" + entityType + "'                class='" + entityClass + "'>" + entityHtml + "</a>");
        ANTT.cloneCopyEvent(this.element[0], newElement[0]);
        this.linkedEntity = {
          uri: entityUri,
          type: entityType,
          label: entityEnhancement.getLabel()
        };
        this.element.replaceWith(newElement);
        this.element = newElement.addClass(styleClass);
        console.info("created enhancement in", this.element);
        this._updateTitle();
        this._insertLink();
        return this._trigger('select', null, {
          linkedEntity: this.linkedEntity,
          textEnhancement: entityEnhancement.getTextEnhancement(),
          entityEnhancement: entityEnhancement
        });
      },
      close: function(event) {
        if (this.menu) {
          this.menu.destroy();
          this.menu.element.remove();
          delete this.menu;
        }
        if (this.dialog) {
          this.dialog.destroy();
          this.dialog.element.remove();
          this.dialog.uiDialogTitlebar.remove();
          return delete this.dialog;
        }
      },
      _updateTitle: function() {
        var title;
        if (this.dialog) {
          if (this.isAnnotated()) {
            title = "" + this.linkedEntity.label + " <small>@ " + (this._sourceLabel(this.linkedEntity.uri)) + "</small>";
          } else {
            title = this.element.text();
          }
          return this.dialog._setOption('title', title);
        }
      },
      _createMenu: function() {
        var ul;
        ul = $('<ul></ul>').appendTo(this.dialog.element);
        this._renderMenu(ul, this.entityEnhancements);
        return this.menu = ul.menu({
          select: __bind(function(event, ui) {
            console.info("selected menu item", ui.item);
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
        return console.info('rendered menu for the elements', entityEnhancements);
      },
      _renderItem: function(ul, eEnhancement) {
        var active, label, source, type;
        label = eEnhancement.getLabel();
        type = this._typeLabels(eEnhancement.getTypes());
        source = this._sourceLabel(eEnhancement.getUri());
        active = this.linkedEntity && eEnhancement.getUri() === this.linkedEntity.uri ? " class='ui-state-active'" : "";
        return $("<li" + active + "><a href='#'>" + label + " <small>(" + type + " from " + source + ")</small></a></li>").data('enhancement', eEnhancement).appendTo(ul);
      },
      _createSearchbox: function() {
        var searchEntryField, sugg, widget;
        searchEntryField = $('<span style="background: fff;"><label for="search"></label><input class="search"></span>').appendTo(this.dialog.element);
        sugg = this.textEnhancements[0];
        widget = this;
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
                    label: "" + (ANTT.getRightLabel(entity)) + " @ " + (widget._sourceLabel(entity.id)),
                    _label: ANTT.getRightLabel(entity),
                    getLabel: function() {
                      return this._label;
                    },
                    getUri: function() {
                      return this.key;
                    },
                    _tEnh: sugg,
                    getTextEnhancement: function() {
                      return this._tEnh;
                    }
                  });
                }
                return _results;
              })();
              return resp(res);
            });
          },
          select: __bind(function(e, ui) {
            this.annotate(ui.item, "acknowledged");
            return console.info(e.target);
          }, this)
        }).focus(200);
        return console.info("show searchbox");
      },
      addTextEnhancement: function(textEnh) {
        this.options.textEnhancements = this.options.textEnhancements || [];
        this.options.textEnhancements.push(textEnh);
        return this.textEnhancements = this.options.textEnhancements;
      }
    });
    return window.ANTT = ANTT;
  })(jQuery);
}).call(this);
