<#import "/imports/common.ftl" as common>
<#escape x as x?html>
<@common.page title="Enhancer VIE" hasrestapi=true> 

<div class="panel" id="webview"
     xmlns:sioc="http://rdfs.org/sioc/ns#">

    <em><strong>Disclaimer</strong>: Hello World :-)</em>
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
        
        $('#enhanceButton').button().click(function(){
            $('#webview article div').vie2().vie2('analyze', function(d){
                console.info('vie2.analyze done:', d);
                alert(d);
            })
        });
    });
    </script>
    <article typeof="sioc:Post" about="http://stanbol.apache.org/enhancertest">
        <div property="sioc:content">
            This is not the content yet.. Edit it!
        </div>
    </article>
    <button id="enhanceButton">Enhance!</button>
</div>

</@common.page>
</#escape>
