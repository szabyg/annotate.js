(function(jQuery, undefined) {
    jQuery.widget('VIE.editable', {
        options: {
            editables: [],
            model: null,
            editor: 'aloha',
            addButton: null,
            enable: function() {},
            enableproperty: function() {},
            disable: function() {},
            activated: function() {},
            deactivated: function() {},
            changed: function() {}
        },
    
        _create: function() {
            if (!this.options.model) {
                this.options.model = VIE.RDFaEntities.getInstance(this.element);
            }
        },
        
        _init: function() {
            if (this.options.disabled) {
                this.disable();
                return;
            }
            this.enable();
        },
        
        enable: function() {      
            var widget = this;
            VIE.RDFa.findPredicateElements(this.options.model.id, jQuery('[property]', this.element), false).each(function() {
                return widget._enableProperty(jQuery(this));
            });
            
            _.forEach(VIE.RDFaEntities.CollectionViews, function(view) {
                widget._enableCollection(view.collection, view.element);
            });
            
            this._trigger('enable', null, {
                instance: this.options.model,
                entityElement: this.element
            });
        },
        
        disable: function() {
            jQuery.each(this.options.editables, function(index, editable) {
                editable.setUnmodified();
                if (typeof editable.changeTimer !== 'undefined') {
                    window.clearInterval(editable.changeTimer);
                }
                try {
                    editable.destroy();
                } catch (err) {
                }
            });
            this.options.editables = [];
            
            if (this.options.addButton) {
                this.options.addButton.remove();
                delete this.options.addButton;
            }

            this._trigger('disable', null, {
                instance: this.options.model,
                entityElement: this.element
            });
        },
        
        _enableProperty: function(element) {
            var propertyName = VIE.RDFa.getPredicate(element);
            if (!propertyName) {
                return true;
            }
            if (this.options.model.get(propertyName) instanceof Array) {
                // For now we don't deal with multivalued properties in Aloha
                return true;
            }
            
            var editable = new Aloha.Editable(element);
            editable.vieEntity = this.options.model;

            // Subscribe to activation and deactivation events
            var widget = this;
            Aloha.EventRegistry.subscribe(editable, 'editableActivated', function() {
                widget._trigger('activated', null, {
                    editable: editable,
                    property: propertyName,
                    instance: widget.options.model,
                    element: element,
                    entityElement: this.element
                });
            });
            Aloha.EventRegistry.subscribe(editable, 'editableDeactivated', function() {
                widget._trigger('deactivated', null, {
                    editable: editable,
                    property: propertyName,
                    instance: widget.options.model,
                    element: element,
                    entityElement: this.element
                });
            });

            // Register a timer to copy any modified contents
            // TODO: Replace with smartContentChange when Aloha .10 is out
            editable.changeTimer = window.setInterval(function() {
                widget._checkModified(propertyName, editable);
            }, 2000);

            this._trigger('enableproperty', null, {
                editable: editable,
                property: propertyName,
                instance: this.options.model,
                element: element,
                entityElement: this.element
            });
            
            this.options.editables.push(editable);
        },
        
        _enableCollection: function(collection, element) {
            var widget = this;

            if (VIE.RDFa.getSubject(element) !== VIE.RDFa._toReference(widget.options.model.id)) {
                return;
            }

            if (widget.options.addButton) {
                return;
            }
            
            view.bind('add', function(itemView) {
                //itemView.el.effect('slide');
                itemView.model.primaryCollection = collection;
                itemView.el.editable({disabled: widget.options.disabled, model: itemView.model});
            });
            
            view.bind('remove', function(itemView) {
                itemView.el.hide('drop');
            });
            
            widget.options.addButton = jQuery('<button>Add</button>').button();
            widget.options.addButton.click(function() {
                collection.add({});
            });
            
            element.after(widget.options.addButton);
        },
        
        _checkModified: function(propertyName, editable) {
            if (!editable.isModified()) {
                return true;
            }
            var changedProperties = {};
            changedProperties[propertyName] = editable.getContents();
            editable.setUnmodified();
            this.options.model.set(changedProperties, {silent: true});
            
            this._trigger('changed', null, {
                editable: editable,
                property: propertyName,
                instance: this.options.model,
                element: editable.obj,
                entityElement: this.element
            });
        }
    });
})(jQuery);
