<#import "/imports/common.ftl" as common>
<#escape x as x?html>
<@common.page title="Enhancer VIE" hasrestapi=true> 

<div class="panel" id="webview"
     xmlns:sioc="http://rdfs.org/sioc/ns#">

    <em><strong>Disclaimer</strong>: Hello World :-)</em>
    <script>
    $(document).ready(function(){
        $('#webview article').hallo({
            plugins: {
              'halloformat': {}
            },
            editable: true
        });
    });
    </script>
    <article typeof="sioc:Post" about="http://stanbol.apache.org/enhancertest">
        <div property="sioc:content">
            This is not the content yet.. Edit it!
        </div>
    </article>
</div>

</@common.page>
</#escape>
