## Features

* Text-Enhancement support
* Spell-checker - like interaction with annotation enhancements
* Write RDFa into your content
* Independent of any editor
* One-line integration
* Configurable Enhancement types

## Goals

* Provide Text enhancement directly in your content
* Provide another open source (MIT license), flexibly usable, easy to integrate tool for (semi-)automatic and manual semantic enhancement.
* A tool that's fun to integrate

        var stanbolConnector = new StanbolConnector({
            "enhancer_url" : "http://example.com/engines/",
            "entityhub_url" : "http://example.com/entityhub/"
        });
        $('#content').annotate({
            connector: stanbolConnector
        });
## Additional planned features

* Manual annotation - loosely coupled wysiwyg-editor enhancement?, needs selection-support
* Connection to VIE - loosely coupled, easy integration
* Clean up decoupling from the stanbol backend - schema mapping
* Entity preview using client-side templating
* Edit relationships

## Dependencies

* jQuery 1.5
* jQuery UI 1.9m5
* Backbone.js
* a wysiwyg-editor with save() (here: hallo editor)
* VIE, VIE^2 (optional)


