/**
 * jQuery Lightbox
 * Version 0.5 - 11/29/2007
 * @author Warren Krewenki
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
            
            var mainNode = '<img id="lightboxImage">';

            var outerImage = '<div id="outerImageContainer"><div id="imageContainer"><iframe id="lightboxIframe"></iframe><div id="loading"><a href="javascript://" id="loadingLink"><img src="'+opts.fileLoadingImage+'"></a></div></div></div>';

            var imageData = '<div id="imageDataContainer" class="clearfix"><div id="imageData"><div id="imageDetails"><span id="caption"></span><span id="numberDisplay"></span></div></div></div>';

            var string;

            if (opts.navbarOnTop) {
              string = '<div id="overlay"></div><div id="lightbox">' + imageData + outerImage + '</div>';
              $("body").append(string);
              $("#imageDataContainer").addClass('ontop');
            } else {
              string = '<div id="overlay"></div><div id="lightbox">' + outerImage + imageData + '</div>';
              $("body").append(string);
            }

            $("#overlay").click(function(){ end(); }).hide();
            $("#lightbox").click(function(){ end();}).hide();
            $("#loadingLink").click(function(){ end(); return false;});
            $('#outerImageContainer').width(opts.widthCurrent).height(opts.heightCurrent);
            $('#imageDataContainer').width(opts.widthCurrent);
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
            var width = opts.width ||
                        window.innerWidth ||
                        document.documentElement.clientWidth ||
                        document.body.clientWidth;
            var height = opts.height ||
                         window.innerHeight ||
                         document.documentElement.clientHeight ||
                         document.body.clientHeight;
            width *= (opts.widthFactor || 0.9);
            height *= (opts.heightFactor || 0.7);
            $('#lightboxIframe')
                .attr('src', opts.src)
                .height(height)
                .width(width)
                .css('border', 'none')
                .load(function() {
                    resizeImageContainer(width, height);
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
        
        function resizeImageContainer(imgWidth, imgHeight) {
            // get current width and height
            opts.widthCurrent = $("#outerImageContainer").outerWidth();
            opts.heightCurrent = $("#outerImageContainer").outerHeight();
            
            // get new width and height
            var widthNew = Math.max(350, imgWidth  + (opts.borderSize * 2));
            var heightNew = (imgHeight  + (opts.borderSize * 2));

            // scalars based on change from old to new
            opts.xScale = ( widthNew / opts.widthCurrent) * 100;
            opts.yScale = ( heightNew / opts.heightCurrent) * 100;

            // calculate size difference between new and old image, and resize if necessary
            wDiff = opts.widthCurrent - widthNew;
            hDiff = opts.heightCurrent - heightNew;

            $('#imageDataContainer')
                .animate({width: widthNew}, opts.resizeSpeed, 'linear');
            $('#outerImageContainer')
                .animate(
                    {width: widthNew}, opts.resizeSpeed, 'linear',
                    function() {
                        $('#outerImageContainer').animate(
                            {height: heightNew},opts.resizeSpeed,'linear',
                            function(){ showIframe(); }
                        );
                    })
                ;

            // if new and old image are same size and 
            // no scaling transition is necessary,
            // do a quick pause to prevent image flicker.
            if((hDiff == 0) && (wDiff == 0)){
                if (jQuery.browser.msie){ pause(250); } else { pause(100);}
            }
        };
        
        function showIframe() {
            $('#loading').hide();
            $('#lightboxIframe').fadeIn("fast");
            opts.inprogress = false;
        };
    };
        
    $.lightbox.parseJsonData = function(data) {
        var imageArray = [];
        
        $.each(data, function(){
            imageArray.push(new Array(this.url, this.title));
        });
        
        return imageArray;
    };

    $.lightbox.defaults = {
        fileLoadingImage : 'images/loading.gif',
        overlayOpacity : 0.8,
        borderSize : 10,
        imageArray : new Array,
        activeImage : null,
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
