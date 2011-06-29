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
.entity.acknowledged.person       {background-color: #ff9;}
.entity.acknowledged.place        {background-color: #f9d;}
.entity.acknowledged.organisation {background-color: #9ff;}
*/
</style>
<div class="panel" id="webview"
     xmlns:sioc="http://rdfs.org/sioc/ns#"
     xmlns:schema="http://www.schema.org/">

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
                x={};
                x[ui.entityEnhancement.getUri()] = ui.entityEnhancement;
                VIE.EntityManager.getByRDFJSON(x);
                console.info('select event', event, ui);
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
        })
        .trigger('click');
    });
    </script>
    <article typeof="schema:CreativeWork" about="http://stanbol.apache.org/enhancertest">
        <div property="sioc:content">
Turkey, known officially as the Republic of Turkey, is a Eurasian country that stretches across the Anatolian peninsula in western Asia and Thrace in the Balkan region of southeastern Europe. Turkey is one of the six independent Turkic states. Turkey is bordered by eight countries: Bulgaria to the northwest; Greece to the west; Georgia to the northeast; Armenia, Azerbaijan and Iran to the east; and Iraq and Syria to the southeast. The Mediterranean Sea and Cyprus are to the south; the Aegean Sea to the west; and the Black Sea is to the north. The Sea of Marmara, the Bosphorus and the Dardanelles (which together form the Turkish Straits) demarcate the boundary between Eastern Thrace and Anatolia; they also separate Europe and Asia. Turks began migrating into the area now called Turkey ("land of the Turks") in the eleventh century. The process was greatly accelerated by the Seljuk victory over the Byzantine Empire at the Battle of Manzikert. Several small beyliks and the Seljuk Sultanate of Rûm ruled Anatolia until the Mongol Empire's invasion. Starting from the thirteenth century, the Ottoman beylik united Anatolia and created an empire encompassing much of Southeastern Europe, Western Asia and North Africa. After the Ottoman Empire collapsed following its defeat in World War I, parts of it were occupied by the victorious Allies. A cadre of young military officers, led by Mustafa Kemal Atatürk, organized a successful resistance to the Allies; in 1923, they would establish the modern Republic of Turkey with Atatürk as its first president. Turkey's location at the crossroads of Europe and Asia makes it a country of significant geostrategic importance. The predominant religion in Turkey is Islam with small minorities of Christianity and Judaism. The country's official language is Turkish, whereas Kurdish and Zazaki languages are spoken by Kurds and Zazas which comprise 18% of the population. Turkey is a democratic, secular, unitary, constitutional republic, with an ancient cultural heritage. Turkey has become increasingly integrated with the West through membership in organizations such as the Council of Europe, NATO, OECD, OSCE and the G-20 major economies. Turkey began full membership negotiations with the European Union in 2005, having been an associate member of the European Economic Community since 1963 and having reached a customs union agreement in 1995. Turkey has also fostered close cultural, political, economic and industrial relations with the Middle East, the Turkic states of Central Asia and the African countries through membership in organizations such as the Organisation of the Islamic Conference and Economic Cooperation Organization. Given its strategic location, large economy and army, Turkey is classified as a regional power.
Actress Angelina Jolie, a longtime goodwill ambassador for the United Nations' refugee agency, will be headed to Turkey this week to visit Syrian refugees, Turkey's Foreign Ministry said Wednesday.
Jolie is expected to arrive in Istanbul and head to Hatay on Friday, according to the ministry, which accepted an application for her visit on Wednesday.
More than 8,000 Syrians have fled their country for Turkey to escape violence, including a military offensive in the Jisr al-Shugur area.
Jolie was named a goodwill ambassador for the Office of the High Commissioner for Refugees in early 2001 and has visited more than 20 countries "to highlight the plight of millions of uprooted people and to advocate for their protection."
The office said her interest in "humanitarian affairs was piqued in 2000 when she went to Cambodia to film the adventure film 'Tomb Raider.' "
Jolie has won numerous acting awards, including a best supporting actress Academy Award for her performance in 1999's "Girl, Interrupted."
        </div>
    </article>
    <button id="enhanceButton">Enhance!</button>
    <div typeof="http://purl.org/dc/dcmitype/Collection" rel="dcterms:hasPart" about="http://example.com/stanbol-webenhancer">
        <article typeof="sioc:Post" about="http://example.net/blog/news_item">
            <h1 property="dcterms:title">News item title</h1>
            <div property="sioc:content">
                <p>
                Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequat. Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi.
                </p>
                <p>
                Nam liber tempor cum soluta nobis eleifend option congue nihil imperdiet doming id quod mazim placerat facer possim assum. Typi non habent claritatem insitam; est usus legentis in iis qui facit eorum claritatem. Investigationes demonstraverunt lectores legere me lius quod ii legunt saepius. Claritas est etiam processus dynamicus, qui sequitur mutationem consuetudium lectorum. Mirum est notare quam littera gothica, quam nunc putamus parum claram, anteposuerit litterarum formas humanitatis per seacula quarta decima et quinta decima. Eodem modo typi, qui nunc nobis videntur parum clari, fiant sollemnes in futurum.
                </p>
            </div>
        </article>
    </div>
</div>

</@common.page>
</#escape>
