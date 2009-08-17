/**
 * jQuery Lightbox
 * Version 0.5 - 11/29/2007
 * @author Warren Krewenki
 *
 * Patched heavily so support iframes by Kevin Jones
 *
 * This package is distributed under the BSD license.
 * For full license information, see LICENSE.TXT
 *
 * Based on Lightbox 2 by Lokesh Dhakar (http://www.huddletogether.com/projects/lightbox2/)
 * Originally written to make use of the Prototype framework, and Script.acalo.us, now altered to use jQuery.
 *
 *
 **/

(function($){

    $.lightbox = function(options){
        // build main options
        var opts = $.extend({}, $.lightbox.defaults, options);
        // initalize the lightbox
        initialize();
        start(this);
        
        /**
         * initalize()
         *
         * @return void
         * @author Warren Krewenki
         */
         
        function initialize() {
            $('#overlay').remove();
            $('#lightbox').remove();
            opts.inprogress = false;

            $('<div id="overlay"></div>').appendTo('body');
            $('<div id="lightbox"></div>').appendTo('body').append(
                $('<div id="lightboxContent"></div>')
            );
            $('#lightboxContent').append(
                $('<iframe id="lightboxIframe"></iframe>'),
                $('<div id="loading"></div>')
                    .html('<a href="javascript://" id="loadingLink"><img src="'+opts.fileLoadingImage+'"></a>')
            );

            $('<a id="closeButton" class="button" href="#"></a>')
                .html('<img src="/images/close.gif" />')
                .appendTo('#lightboxContent');

            $("#overlay").click(function(){ end(); }).hide();
            $("#closeButton").click(function(){ end(); }).hide();
            $("#lightbox").click(function(){ end();}).hide();
            $("#loadingLink").click(function(){ end(); return false;});
        };
        
        function getPageSize() {
            var jqueryPageSize = new Array($(document).width(),$(document).height(), $(window).width(), $(window).height());
            return jqueryPageSize;
        };
        
        function getPageScroll() {
            var xScroll, yScroll;

            if (self.pageYOffset) {
                yScroll = self.pageYOffset;
                xScroll = self.pageXOffset;
            } else if (document.documentElement && document.documentElement.scrollTop){  // Explorer 6 Strict
                yScroll = document.documentElement.scrollTop;
                xScroll = document.documentElement.scrollLeft;
            } else if (document.body) {// all other Explorers
                yScroll = document.body.scrollTop;
                xScroll = document.body.scrollLeft;
            }

            var arrayPageScroll = new Array(xScroll,yScroll);
            return arrayPageScroll;
        };
        
        function pause(ms) {
            var date = new Date();
            var curDate = null;
            do{curDate = new Date();}
            while(curDate - date < ms);
        };
        
        function start(imageLink) {
            $("select, embed, object").hide();
            var arrayPageSize = getPageSize();
            $("#overlay").hide().css({width: '100%', height: arrayPageSize[1]+'px', opacity : opts.overlayOpacity}).fadeIn();
            imageNum = 0;

            // if data is not provided by jsonData parameter
            if(!opts.jsonData) {
                opts.imageArray = [];
                // if image is NOT part of a set..
                if(!imageLink.rel || (imageLink.rel == '')){
                    // add single image to Lightbox.imageArray
                    opts.imageArray.push(new Array(imageLink.href, opts.displayTitle ? imageLink.title : ''));
                } else {
                // if image is part of a set..
                    $("a").each(function(){
                        if(this.href && (this.rel == imageLink.rel)){
                            opts.imageArray.push(new Array(this.href, opts.displayTitle ? this.title : ''));
                        }
                    });
                }
            }
        
            if(opts.imageArray.length > 1) {
                for(i = 0; i < opts.imageArray.length; i++){
                    for(j = opts.imageArray.length-1; j>i; j--){
                        if(opts.imageArray[i][0] == opts.imageArray[j][0]){
                            opts.imageArray.splice(j,1);
                        }
                    }
                }
                while(opts.imageArray[imageNum][0] != imageLink.href) { imageNum++;}
            }

            // calculate top and left offset for the lightbox
            var arrayPageScroll = getPageScroll();
            var lightboxTop = arrayPageScroll[1] + (arrayPageSize[3] / 10);
            var lightboxLeft = arrayPageScroll[0];
            $('#lightbox').css({top: lightboxTop+'px', left: lightboxLeft+'px'}).show();

            changeImage(imageNum);
        };
        
        function changeImage(imageNum) {
            if(opts.inprogress == false){
                opts.inprogress = true;
                opts.activeImage = imageNum;    // update global var

                // hide elements during transition
                $('#loading').show();
                $('#lightboxImage').hide();
                $('#hoverNav').hide();
                $('#prevLink').hide();
                $('#nextLink').hide();
                doChangeImage();
            }
        };
        
        function doChangeImage() {
            $('#lightboxIframe')
                .attr('src', opts.src)
                .css({
                    border: 'none',
                    height: '100%',
                    width: '100%'
                })
                .load(function() {
                    resize();
                    var win;
                    try { win = this.contentWindow } catch (e) {}
                    if (win) win.closeLightbox = end;
                });
        };
        
        function end() {
            $('#lightbox').hide();
            $('#overlay').fadeOut();
            $('select, object, embed').show();
        };
        
        function resize() {
            var windowWidth = window.innerWidth ||
                              document.documentElement.clientWidth ||
                              document.body.clientWidth;
            var windowHeight = window.innerHeight ||
                              document.documentElement.clientHeight ||
                              document.body.clientHeight;
            var desiredWidth = windowWidth * (opts.widthFactor || 0.9);
            var desiredHeight = windowHeight * (opts.HeightFactor || 0.4);
            desiredWidth += (opts.borderSize * 2);
            desiredHeight += (opts.borderSize * 2);

            var win = $('#lightboxIframe').get(0).contentWindow;

            $('#lightboxContent')
                .animate(
                    {width: desiredWidth}, opts.resizeSpeed, 'linear',
                    function() {
                        $('#lightboxContent').animate(
                            {height: desiredHeight}, opts.resizeSpeed, 'linear',
                            function(){ showIframe(); return false }
                        );
                        return false;
                    });
        };
        
        function showIframe() {
            $('#loading').hide();
            $('#lightboxIframe').fadeIn("fast", function() {
                $('#closeButton').show();
            });
            opts.inprogress = false;
        };
    };
        
    $.lightbox.defaults = {
        fileLoadingImage : 'images/loading.gif',
        overlayOpacity : 0.8,
        borderSize : 10,
        inprogress : false,
        resizeSpeed : 350,
        widthCurrent: 250,
        heightCurrent: 250,
        xScale : 1,
        yScale : 1,
        displayTitle: true,
        navbarOnTop: false,
        slideNavBar: false, // slide nav bar up/down between image resizing transitions
        navBarSlideSpeed: 350,
        displayHelp: false,
        strings : {
            help: ' \u2190 / P - previous image\u00a0\u00a0\u00a0\u00a0\u2192 / N - next image\u00a0\u00a0\u00a0\u00a0ESC / X - close image gallery',
            prevLinkTitle: 'previous image',
            nextLinkTitle: 'next image',
            prevLinkText:  '&laquo; Previous',
            nextLinkText:  'Next &raquo;',
            closeTitle: 'close image gallery',
            image: 'Image ',
            of: ' of '
        },
        fitToScreen: false,        // resize images if they are bigger than window
        disableNavbarLinks: false,
        loopImages: false,
        imageClickClose: true,
        jsonData: null,
        jsonDataParser: null
    };
    
})(jQuery);
