<#import "/imports/common.ftl" as common>
<#escape x as x?html>
<@common.page title="Enhancer VIE" hasrestapi=true> 

<style>
article {
    padding: 10px;
}
span.entity,
a[typeof][about] {
    z-index: -1;
    margin: -3px;
    padding: 1px;
    background-color: #E0E0E0;
    /* box-shadow: 2px 2px 5px grey;*/
    border-radius: 3px;
    border: outset rgba(0, 0, 0, 0.1);
    white-space: nowrap;
    border-width:2px;
}
a[typeof][about] {border-radius:1px;border-width:1px;}
a[typeof][about] {color: black}
.entity.withSuggestions {border-color: rgba(0, 0, 0, 0.5);}

.entity.person, 
a[typeof][about].person       {background-color: #ffe;}

.entity.place,
a[typeof][about].place        {background-color: #fef;}

.entity.organisation,
a[typeof][about].organisation {background-color: #eff;}

/*
.entity.concept,
a[typeof][about].concept {background-color: #eef;}

.entity.acknowledged.person       {background-color: #ff9;}
.entity.acknowledged.place        {background-color: #f9d;}
.entity.acknowledged.organisation {background-color: #9ff;}
*/
</style>
<div class="panel" id="webview"
     xmlns:sioc="http://rdfs.org/sioc/ns#"
     xmlns:schema="http://www.schema.org/"
     xmlns:enhancer="http://fise.iks-project.eu/ontology/"
     xmlns:dc="http://purl.org/dc/terms/">

    <script>
    VIE2.logLevels=[];
    $(document).ready(function(){
        VIE2.connectors['stanbol'].options({
            "enhancer_url" : "/engines/",
            "entityhub_url" : "/entityhub/"
        });

        // Implement our own Backbone.sync method
        Backbone.sync = function(method, model, options) {
            console.log('Backbone.sync', method, model.toJSONLD());
        };
        

        VIE.CollectionManager.loadCollections();
        VIE.RDFaEntities.getInstances();

        $('article.active-enhancement').remove();
        $('#webview article').hallo({
            plugins: {
              'halloformat': {}
            },
            editable: true
        });
        $('#webview article div').annotate({
            connector: VIE2.connectors['stanbol'],
            debug: true,
            decline: function(event, ui){
                console.info('decline event', event, ui);
            },
            select: function(event, ui){
                console.info('select event', event, ui);
            },
            remove: function(event, ui){
                console.info('remove event', event, ui);
            }

        });
        
        $('#enhanceButton')
        .button({enhState: 'passiv'})
        .click(function(){
            // Button with two states
            var oldState = $(this).button('option', 'enhState');
            var newState = oldState === 'passiv' ? 'active' : 'passiv';
            $(this).button('option', 'enhState', newState);
            if($(this).button('option', 'enhState') === 'active'){
                // annotate.enable()
                $('#webview article div').annotate('enable');
                $(this).button('option', 'label', 'Done');
            } else {
                // annotate.disable()
                $('#webview article div').annotate('disable');
                $(this).button('option', 'label', 'Enhance!');
            }
        });
    });
    </script>
    <article typeof="schema:CreativeWork" about="http://stanbol.apache.org/enhancertest">
        <div property="sioc:content">
            Text to analyze..
        </div>
    </article>
    <button id="enhanceButton">Enhance!</button>

</div>

</@common.page>
</#escape>
