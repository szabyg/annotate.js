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
                $(this).button('option', 'label', 'Done');
                $('#webview article div').annotate('enable');
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
            Chemoprevention with aspirin reduces the recurrence of colonic adenomas greater than 5 mm in diameter after 1 year in patients who had previous colorectal adenomas, reported Dr. Robert Benamouzig of Avicenne Hospital, Bobigny, France, and his associates
        </div>
    </article>
    <button id="enhanceButton">Enhance!</button>
    
<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>

    <hr/>
    <div class="panel">
        <h3>Featuring annotate.js</h3>
        <h3>Features</h3>
        <ul>
            <li>Text-Enhancement support</li>
            <li>Spell-checker - like interaction with annotation enhancements</li>
            <li>Write RDFa into your content</li>
            <li>Independent of any editor</li>
            <li>One-line integration</li>
            <li>Configurable Enhancement types</li>
        </ul>

        <h3>Goals</h3>
        <ul>
            <li>Provide Text enhancement directly in your content</li>
            <li>Provide another open source (MIT license), flexibly usable, easy to 
                integrate tool for (semi-)automatic and manual semantic enhancement.</li>
            <li>
                A tool that's fun to integrate 
                <pre>
    var stanbolConnector = new StanbolConnector({
        "enhancer_url" : "http://example.com/engines/",
        "entityhub_url" : "http://example.com/entityhub/"
    });
    $('#content').annotate({
        connector: stanbolConnector
    });
                </pre>
            </li>
        </ul>
        <h3>Additional planned features</h3>
        <ul>
            <li>Manual annotation - loosely coupled wysiwyg-editor enhancement?, 
                needs selection-support</li>
            <li>Connection to VIE - loosely coupled, easy integration</li>
            <li>Clean up decoupling from the stanbol backend - schema mapping</li>
            <li>Preview with client-side templating with jquery</li>
            <li>Support Mocroformat</li>
            <li>Edit relationships</li>
        <ul>
        <h3>Dependencies</h3>
        <ul>
            <li>jQuery 1.5</li>
            <li>jQuery UI 1.9m5</li>
            <li>Backbone.js</li>
            <li>a wysiwyg-editor with save() (here: <a href="https://github.com/bergie/hallo">hallo editor</a>)</li>
            <li>VIE, VIE^2 (optional)</li>
        <ul>
        
    </div>
</div>

</@common.page>
</#escape>
