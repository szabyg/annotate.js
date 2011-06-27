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
        .trigger('click');
        $('#enhanceDisableButton').button().click(function(){
            $('#webview article div').annotate('disable');
        })

    });
    </script>
    <article typeof="schema:CreativeWork" about="http://stanbol.apache.org/enhancertest">
        <div property="sioc:content">
Actress Angelina Jolie, a longtime goodwill ambassador for the United Nations' refugee agency, will be headed to Turkey this week to visit Syrian refugees, Turkey's Foreign Ministry said Wednesday.
Jolie is expected to arrive in Istanbul and head to Hatay on Friday, according to the ministry, which accepted an application for her visit on Wednesday.
More than 8,000 Syrians have fled their country for Turkey to escape violence, including a military offensive in the Jisr al-Shugur area.
Jolie was named a goodwill ambassador for the Office of the High Commissioner for Refugees in early 2001 and has visited more than 20 countries "to highlight the plight of millions of uprooted people and to advocate for their protection."
The office said her interest in "humanitarian affairs was piqued in 2000 when she went to Cambodia to film the adventure film 'Tomb Raider.' "
Jolie has won numerous acting awards, including a best supporting actress Academy Award for her performance in 1999's "Girl, Interrupted."
        </div>
    </article>
    <button id="enhanceButton">Enhance!</button>
    <button id="enhanceDisableButton">disable</button>
    
</div>

</@common.page>
</#escape>
