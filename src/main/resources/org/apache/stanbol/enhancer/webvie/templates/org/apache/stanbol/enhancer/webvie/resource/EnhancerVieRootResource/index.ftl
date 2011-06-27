<#import "/imports/common.ftl" as common>
<#escape x as x?html>
<@common.page title="Enhancer VIE" hasrestapi=true> 

<style>
article {
    padding: 10px;
}
span.entity {
    z-index: -1;
    margin: -3px;
    padding: 1px;
    background-color: #E0E0E0;
    /* box-shadow: 2px 2px 5px grey;*/
    border-radius: 4px;
    border: outset rgba(0, 0, 0, 0.1);
    white-space: nowrap;
}
.entity.withSuggestions {border-color: rgba(0, 0, 0, 0.5);}

.entity.Person       {background-color: #ffe;}
.entity.Place        {background-color: #fef;}
.entity.Organisation {background-color: #eff;}

.entity.acknowledged.Person       {background-color: #ff9;}
.entity.acknowledged.Place        {background-color: #f9d;}
.entity.acknowledged.Organisation {background-color: #9ff;}
</style>
<div class="panel" id="webview"
     xmlns:sioc="http://rdfs.org/sioc/ns#"
     xmlns:schema="http://www.schema.org/">

    <script>
    $(document).ready(function(){
        VIE2.connectors['stanbol'].options({
            "enhancer_url" : "/engines/",
            "entityhub_url" : "/entityhub/"
        });

        $('#webview article').hallo({
            plugins: {
              'halloformat': {}
            },
            editable: true
        });
        $('#webview article div').annotate({
            decline: function(event, ui){
                console.info('decline event', event, ui);
            },
            select: function(event, ui){
                console.info('select event', event, ui);
            }

        });
        
        $('#enhanceButton').button().click(function(){
            $('#webview article div').annotate('enable');
        })
        $('#enhanceDisableButton').button().click(function(){
            $('#webview article div').annotate('disable');
        })

    });
    </script>
    <article typeof="schema:CreativeWork" about="http://stanbol.apache.org/enhancertest">
        <div property="sioc:content">
            Text to analyze..
        </div>
    </article>
    <button id="enhanceButton">Enhance!</button>
    <button id="enhanceDisableButton">disable</button>
    
</div>

</@common.page>
</#escape>
