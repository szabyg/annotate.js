# Annotate.js (coffeescript)
## Introduction
Annotate.js is the frontend widget for entity recognition back-end engines like Stanbol.

## Features

* Text-Enhancement support
* Spell-checker - like interaction with annotation enhancements
* Write RDFa into your content
* Independent of any editor
* One-line integration
* Configurable Enhancement types

## Options
* 'vie': VIE instance to use. Default is a simple VIE instance with Stanbol service 
configured to connect http://dev.iks-project.eu:8080 which is the actual demo stable launcher.
* 'vieServices': defines which services to use for the annotation. Default ['stanbol']
* 'autoAnalyze': fire analyze on initialization
* 'showTooltip': (don't) show a preview tooltip when mouseovering an already annotated word.
* 'typeFilter': Annotation Type(s) to filter for. Default empty. Example: 
["http://dbpedia.org/ontology/Place", "http://dbpedia.org/ontology/Organisation", "http://dbpedia.org/ontology/Person"]
* 'debug': Shows console messages about what's happening
* 'ns': map of relevant namespaces. Default is DBpedia and SKOS namespace definitions.
* 'fallbackLanguage': 

## Methods
* 'enable' gets enhancements from backend and visualizes them on the analized dom element.
* 'disable' hides all the text enhancements that are not accepted by the user.
* 'acceptAll' goes through all text enhancements and accepts the best candidate
automatically.

## Events
* 'success': finished loading annotations
* 'error': error loading annotations
* 'select': User selected an annotation
* 'decline': User declined a suggestion
* 'remove': User removed a previously selected annotation

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

## Future features

* Manual annotation - loosely coupled wysiwyg-editor enhancement?, needs selection-support
* Connection to VIE - loosely coupled, easy integration
* Clean up decoupling from the stanbol backend - schema mapping
* Entity preview using client-side templating
* Edit relationships

## Dependencies

* jQuery 1.5
* jQuery UI 1.9m5
* Backbone.js
* a wysiwyg-editor with save() (here: [hallo editor](https://github.com/bergie/hallo))
* VIE, VIE^2 (optional)

## Development guide
The widget development is done in [CoffeeScript](http://jashkenas.github.com/coffee-script/). Use the following command to automatically compile the script in the background whenever it's edited:

    $ coffee -c -w -o lib src/*.coffee

## Apache ProxyPass settings
In order to use annotate.js on a different site other than where your stanbol instance is running you'll need a proxy for avoiding [cross-site scripting](http://en.wikipedia.org/wiki/Cross-site_scripting). One way of doing this is to set up your server to redirect requests e.g. going to `http://yoursite.com/stanbol/abc` to `http://stanbolsite.com:8080/abc`. On an apache server this could be done with the following configuration snippet put e.g. in `/etc/apache2/conf.d/stanbol`. (You'll also have to enable apache proxy modules) You can use the `dev.iks-project.eu:8080` stanbol instance for testing or replace the address with another stanbol installation your apache server has access to.

    <Proxy http://dev.iks-project.eu:8080>
        Order Allow,Deny
        Allow from all
    </Proxy>
    ProxyPass /stanbol http://dev.iks-project.eu:8080
    ProxyPassReverse /stanbol http://dev.iks-project.eu:8080

