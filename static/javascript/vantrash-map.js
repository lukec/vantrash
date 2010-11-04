// BEGIN static/javascript/libs/egeoxml.js

/*********************************************************************\
*                                                                     *
* egeoxml.js                                         by Mike Williams *
*                                                                     *
* A Google Maps API Extension                                         *
*                                                                     *
* Renders the contents of a My Maps (or similar) KML file             *
*                                                                     *
* Documentation: http://econym.org.uk/gmap/egeoxml.htm                * 
*                                                                     *
***********************************************************************
*                                                                     *
*   This Javascript is provided by Mike Williams                      *
*   Community Church Javascript Team                                  *
*   http://www.bisphamchurch.org.uk/                                  *
*   http://econym.org.uk/gmap/                                        *
*                                                                     *
*   This work is licenced under a Creative Commons Licence            *
*   http://creativecommons.org/licenses/by/2.0/uk/                    *
*                                                                     *
\*********************************************************************/


// Version 0.0   17 Apr 2007 - Initial testing, just markers
// Version 0.1   17 Apr 2007 - Sensible shadows, and a few general improvements
// Version 0.2   18 Apr 2007 - Polylines (non-clickable, no sidebar)
// Version 0.3   18 Apr 2007 - Polygons (non-clickable, no sidebar)
// Version 0.4   18 Apr 2007 - Sidebar entries for polygons
// Version 0.5   19 Apr 2007 - Accept an array of XML filenames, and add the {sortbyname} option
// Version 0.6   19 Apr 2007 - Sidebar entries for polylines, get directions and search nearby
// Version 0.7   20 Apr 2007 - Info Window Styles
// Version 0.8   21 Apr 2007 - baseicon
// Version 0.9   21 Apr 2007 - iwoptions and markeroptions
// Version 1.0   21 Apr 2007 - Launched
// Version 1.1   25 Apr 2007 - Bugfix - would crash if no options were specified
// Version 1.2   25 Apr 2007 - If the description begins with "http://" make it into a link.
// Version 1.3   30 Apr 2007 - printgif, dropbox
// Version 1.4   14 May 2007 - Elabels
// Version 1.5   17 May 2007 - Default values for width, fill and outline
// Version 1.6   21 May 2007 - GGroundOverlay (needs API V2.79+)
// Version 1.7   22 May 2007 - Better icon positioning for MyMaps icons
// Version 1.8   31 May 2007 - polyline bugfix
// Version 1.9   23 Jun 2007 - add .parseString() method
// Version 2.0   23 Jun 2007 - .parseString() handles an array of strings
// Version 2.1   25 Jul 2007 - imagescan
// Version 2.2   10 Aug 2007 - Support new My Maps icons
// Version 2.3   25 Nov 2007 - Clear variables used by .parse() so that it can be rerun
// Version 2.4   08 Dec 2007 - polylineoptions and polygonoptions
// Version 2.5   11 Dec 2007 - EGeoXml.value() trims leading and trailing whitespace 
// Version 2.6   08 Feb 2008 - Trailing whitespace wasn't removed in the previous change
// Version 2.7   14 Oct 2008 - If there's no <description> try looking for <text> instead
// Version 2.8   12 Jan 2009 - Bugfix - last point of poly was omitted
// Version 2.9   05 Feb 2009 - add .hide() .show()

// Constructor

function EGeoXml(myvar, map, url, opts) {
  // store the parameters
  this.myvar = myvar;
  this.map = map;
  this.url = url;
  if (typeof url == "string") {
    this.urls = [url];
  } else {
    this.urls = url;
  }
  this.opts = opts || {};
  // infowindow styles
  this.titlestyle = this.opts.titlestyle || 'style = "font-family: arial, sans-serif;font-size: medium;font-weight:bold;font-size: 100%;"';
  this.descstyle = this.opts.descstyle || 'style = "font-family: arial, sans-serif;font-size: small;padding-bottom:.7em;"';
  this.directionstyle = this.opts.directionstyle || 'style="font-family: arial, sans-serif;font-size: small;padding-left: 1px;padding-top: 1px;padding-right: 4px;"';
  // sidebar/dropbox functions
  this.sidebarfn = this.opts.sidebarfn || EGeoXml.addSidebar;
  this.dropboxfn = this.opts.dropboxfn || EGeoXml.addDropdown;
  // elabel options 
  this.elabelopacity = this.opts.elabelopacity || 100;
  // other useful "global" stuff
  this.bounds = new GLatLngBounds();
  this.gmarkers = [];
  this.gpolylines = [];
  this.gpolygons = [];
  this.groundoverlays = [];
  this.side_bar_html = "";
  this.side_bar_list = [];
  this.styles = []; // associative array
  this.iwwidth = this.opts.iwwidth || 250;
  this.progress = 0;
  this.lastmarker = {};   
  this.myimages = [];
  this.imageNum =0;
}
               
// uses GXml.value, then removes leading and trailing whitespace
EGeoXml.value = function(e) {
  a = GXml.value(e);
  a = a.replace(/^\s*/,"");
  a = a.replace(/\s*$/,"");
  return a;
}

// Create Marker

EGeoXml.prototype.createMarker = function(point,name,desc,style) {
  var icon = G_DEFAULT_ICON;
  var myvar=this.myvar;
  var iwoptions = this.opts.iwoptions || {};
  var markeroptions = this.opts.markeroptions || {};
  var icontype = this.opts.icontype || "style";
  if (icontype == "style") {
    if (!!this.styles[style]) {
      icon = this.styles[style];
    }
  }
  if (!markeroptions.icon) {
    markeroptions.icon = icon;
  }
  var m = new GMarker(point, markeroptions);

  // Attempt to preload images
  if (this.opts.preloadimages) {
    var text = desc;
    var pattern = /<\s*img/ig;
    var result;
    var pattern2 = /src\s*=\s*[\'\"]/;
    var pattern3 = /[\'\"]/;

    while ((result = pattern.exec(text)) != null) {
      var stuff = text.substr(result.index);
      var result2 = pattern2.exec(stuff);
      if (result2 != null) {
        stuff = stuff.substr(result2.index+result2[0].length);
        var result3 = pattern3.exec(stuff);
        if (result3 != null) {
          var imageUrl = stuff.substr(0,result3.index);
          this.myimages[this.imageNum] = new Image();
          this.myimages[this.imageNum].src = imageUrl;
          this.imageNum++;
        }
      }
    }
  }



  if (this.opts.elabelclass) {
    var l = new ELabel(point, name, this.opts.elabelclass, this.opts.elabeloffset, this.elabelopacity, true);
    this.map.addOverlay(l);
  }

  var html = "<div style = 'width:"+this.iwwidth+"px'>"
               + "<h1 "+this.titlestyle+">"+name+"</h1>"
               +"<div "+this.descstyle+">"+desc+"</div>";

  if (this.opts.directions) {
    var html1 = html + '<div '+this.directionstyle+'>'
                     + 'Get Directions: <a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click2\')">To Here</a> - ' 
                     + '<a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click3\')">From Here</a><br>'
                     + '<a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click4\')">Search nearby</a></div>';
    var html2 = html + '<div '+this.directionstyle+'>'
                     + 'Get Directions: To here - '
                     + '<a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click3\')">From Here</a><br>'
                     + 'Start address:<form action="http://maps.google.com/maps" method="get" target="_blank">'
                     + '<input type="text" SIZE=35 MAXLENGTH=80 name="saddr" id="saddr" value="" />'
                     + '<INPUT value="Go" TYPE="SUBMIT">'
                     + '<input type="hidden" name="daddr" value="' + point.lat() + ',' + point.lng() + "(" + name + ")" + '"/>'
                     + '<br><a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click\')">&#171; Back</a></div>';
    var html3 = html + '<div '+this.directionstyle+'>'
                     + 'Get Directions: <a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click2\')">To Here</a> - ' 
                     + 'From Here<br>'
                     + 'End address:<form action="http://maps.google.com/maps" method="get"" target="_blank">'
                     + '<input type="text" SIZE=35 MAXLENGTH=80 name="daddr" id="daddr" value="" />'
                     + '<INPUT value="Go" TYPE="SUBMIT">'
                     + '<input type="hidden" name="saddr" value="' + point.lat() + ',' + point.lng() +  "(" + name + ")" + '"/>'
                     + '<br><a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click\')">&#171; Back</a></div>';
    var html4 = html + '<div '+this.directionstyle+'>'
                     + 'Search nearby: e.g. "pizza"<br>'
                     + '<form action="http://maps.google.com/maps" method="get"" target="_blank">'
                     + '<input type="text" SIZE=35 MAXLENGTH=80 name="q" id="q" value="" />'
                     + '<INPUT value="Go" TYPE="SUBMIT">'
                     + '<input type="hidden" name="near" value="' + name + ' @' + point.lat() + ',' + point.lng() + '"/>'
                   //  + '<input type="hidden" name="near" value="' +  point.lat() + ',' + point.lng() +  "(" + name + ")" + '"/>';
                     + '<br><a href="javascript:GEvent.trigger(' + this.myvar +'.lastmarker,\'click\')">&#171; Back</a></div>';
    GEvent.addListener(m, "click2", function() {
      m.openInfoWindowHtml(html2 + "</div>",iwoptions);
    });
    GEvent.addListener(m, "click3", function() {
      m.openInfoWindowHtml(html3 + "</div>",iwoptions);
    });
    GEvent.addListener(m, "click4", function() {
      m.openInfoWindowHtml(html4 + "</div>",iwoptions);
    });
  } else {
    var html1 = html;
  }

  GEvent.addListener(m, "click", function() {
    eval(myvar+".lastmarker = m");
    m.openInfoWindowHtml(html1 + "</div>",iwoptions);
  });
  if (!!this.opts.addmarker) {
    this.opts.addmarker(m,name,desc,icon.image,this.gmarkers.length)
  } else {
    this.map.addOverlay(m);
  }
  this.gmarkers.push(m);
  if (this.opts.sidebarid || this.opts.dropboxid) {
    var n = this.gmarkers.length-1;
    this.side_bar_list.push (name + "$$$marker$$$" + n +"$$$" );
  }
}

// Create Polyline

EGeoXml.prototype.createPolyline = function(points,color,width,opacity,pbounds,name,desc) {
  var thismap = this.map;
  var iwoptions = this.opts.iwoptions || {};
  var polylineoptions = this.opts.polylineoptions || {};
  var p = new GPolyline(points,color,width,opacity,polylineoptions);
  this.map.addOverlay(p);
  this.gpolylines.push(p);
  var html = "<div style='font-weight: bold; font-size: medium; margin-bottom: 0em;'>"+name+"</div>"
             +"<div style='font-family: Arial, sans-serif;font-size: small;width:"+this.iwwidth+"px'>"+desc+"</div>";
  GEvent.addListener(p,"click", function() {
    thismap.openInfoWindowHtml(p.getVertex(Math.floor(p.getVertexCount()/2)),html,iwoptions);
  } );
  if (this.opts.sidebarid) {
    var n = this.gpolylines.length-1;
    var blob = '&nbsp;&nbsp;<span style=";border-left:'+width+'px solid '+color+';">&nbsp;</span> ';
    this.side_bar_list.push (name + "$$$polyline$$$" + n +"$$$" + blob );
  }
}

// Create Polygon

EGeoXml.prototype.createPolygon = function(points,color,width,opacity,fillcolor,fillopacity,pbounds, name, desc) {
  var thismap = this.map;
  var iwoptions = this.opts.iwoptions || {};
  var polygonoptions = this.opts.polygonoptions || {};
  var p = new GPolygon(points,color,width,opacity,fillcolor,fillopacity,polygonoptions)
  this.map.addOverlay(p);
  this.gpolygons.push(p);
  var html = "<div style='font-weight: bold; font-size: medium; margin-bottom: 0em;'>"+name+"</div>"
             +"<div style='font-family: Arial, sans-serif;font-size: small;width:"+this.iwwidth+"px'>"+desc+"</div>";
  GEvent.addListener(p,"click", function() {
    thismap.openInfoWindowHtml(pbounds.getCenter(),html,iwoptions);
  } );
  if (this.opts.sidebarid) {
    var n = this.gpolygons.length-1;
    var blob = '<span style="background-color:' +fillcolor + ';border:2px solid '+color+';">&nbsp;&nbsp;&nbsp;&nbsp;</span> ';
    this.side_bar_list.push (name + "$$$polygon$$$" + n +"$$$" + blob );
  }
}


// Sidebar factory method One - adds an entry to the sidebar
EGeoXml.addSidebar = function(myvar,name,type,i,graphic) {
  if (type == "marker") {
    return '<a href="javascript:GEvent.trigger(' + myvar+ '.gmarkers['+i+'],\'click\')">' + name + '</a><br>';
  }
  if (type == "polyline") {
    return '<div style="margin-top:6px;"><a href="javascript:GEvent.trigger(' + myvar+ '.gpolylines['+i+'],\'click\')">' + graphic + name + '</a></div>';
  }
  if (type == "polygon") {
    return '<div style="margin-top:6px;"><a href="javascript:GEvent.trigger(' + myvar+ '.gpolygons['+i+'],\'click\')">' + graphic + name + '</a></div>';
  }
}

// Dropdown factory method
EGeoXml.addDropdown = function(myvar,name,type,i,graphic) {
    return '<option value="' + i + '">' + name +'</option>';
}

  
// Request to Parse an XML file

EGeoXml.prototype.parse = function() {
  // clear some variables
  this.gmarkers = [];
  this.gpolylines = [];
  this.gpolygons = [];
  this.groundoverlays = [];
  this.side_bar_html = "";
  this.side_bar_list = [];
  this.styles = []; // associative array
  this.lastmarker = {};   
  this.myimages = [];
  this.imageNum =0;
  var that = this;
  this.progress = this.urls.length;
  for (u=0; u<this.urls.length; u++) {
    GDownloadUrl(this.urls[u], function(doc) {that.processing(doc)});
  }
}

EGeoXml.prototype.parseString = function(doc) {
  // clear some variables
  this.gmarkers = [];
  this.gpolylines = [];
  this.gpolygons = [];
  this.groundoverlays = [];
  this.side_bar_html = "";
  this.side_bar_list = [];
  this.styles = []; // associative array
  this.lastmarker = {};   
  this.myimages = [];
  this.imageNum =0;
  if (typeof doc == "string") {
    this.docs = [doc];
  } else {
    this.docs = doc;
  }
  this.progress = this.docs.length;
  for (u=0; u<this.docs.length; u++) {
    this.processing(this.docs[u]);
  }
}


EGeoXml.prototype.processing = function(doc) {
    var that = this;
    var xmlDoc = GXml.parse(doc)
    // Read through the Styles
    var styles = xmlDoc.documentElement.getElementsByTagName("Style");
    for (var i = 0; i <styles.length; i++) {
      var styleID = styles[i].getAttribute("id");
      var icons=styles[i].getElementsByTagName("Icon");
      // This might not be am icon style
      if (icons.length > 0) {
        var href=EGeoXml.value(icons[0].getElementsByTagName("href")[0]);
        if (!!href) {
          if (!!that.opts.baseicon) {
            that.styles["#"+styleID] = new GIcon(that.opts.baseicon,href);
          } else {
            that.styles["#"+styleID] = new GIcon(G_DEFAULT_ICON,href);
            that.styles["#"+styleID].iconSize = new GSize(32,32);
            that.styles["#"+styleID].shadowSize = new GSize(59,32);
            that.styles["#"+styleID].dragCrossAnchor = new GPoint(2,8);
            that.styles["#"+styleID].iconAnchor = new GPoint(16,32);
            if (that.opts.printgif) {
              var bits = href.split("/");
              var gif = bits[bits.length-1];
              gif = that.opts.printgifpath + gif.replace(/.png/i,".gif");
              that.styles["#"+styleID].printImage = gif;
              that.styles["#"+styleID].mozPrintImage = gif;
            }
            if (!!that.opts.noshadow) {
              that.styles["#"+styleID].shadow="";
            } else {
              // Try to guess the shadow image
              if (href.indexOf("/red.png")>-1 
               || href.indexOf("/blue.png")>-1 
               || href.indexOf("/green.png")>-1 
               || href.indexOf("/yellow.png")>-1 
               || href.indexOf("/lightblue.png")>-1 
               || href.indexOf("/purple.png")>-1 
               || href.indexOf("/pink.png")>-1 
               || href.indexOf("/orange.png")>-1 
               || href.indexOf("-dot.png")>-1 ) {
                  that.styles["#"+styleID].shadow="http://maps.google.com/mapfiles/ms/micons/msmarker.shadow.png";
              }
              else if (href.indexOf("-pushpin.png")>-1) {
                  that.styles["#"+styleID].shadow="http://maps.google.com/mapfiles/ms/micons/pushpin_shadow.png";
              }
              else {
                var shadow = href.replace(".png",".shadow.png");
                that.styles["#"+styleID].shadow=shadow;
              }
            }
          }
        }
      }
      // is it a LineStyle ?
      var linestyles=styles[i].getElementsByTagName("LineStyle");
      if (linestyles.length > 0) {
        var width = parseInt(GXml.value(linestyles[0].getElementsByTagName("width")[0]));
        if (width < 1) {width = 5;}
        var color = EGeoXml.value(linestyles[0].getElementsByTagName("color")[0]);
        var aa = color.substr(0,2);
        var bb = color.substr(2,2);
        var gg = color.substr(4,2);
        var rr = color.substr(6,2);
        color = "#" + rr + gg + bb;
        var opacity = parseInt(aa,16)/256;
        if (!that.styles["#"+styleID]) {
          that.styles["#"+styleID] = {};
        }
        that.styles["#"+styleID].color=color;
        that.styles["#"+styleID].width=width;
        that.styles["#"+styleID].opacity=opacity;
      }
      // is it a PolyStyle ?
      var polystyles=styles[i].getElementsByTagName("PolyStyle");
      if (polystyles.length > 0) {
        var fill = parseInt(GXml.value(polystyles[0].getElementsByTagName("fill")[0]));
        var outline = parseInt(GXml.value(polystyles[0].getElementsByTagName("outline")[0]));
        var color = EGeoXml.value(polystyles[0].getElementsByTagName("color")[0]);

        if (polystyles[0].getElementsByTagName("fill").length == 0) {fill = 1;}
        if (polystyles[0].getElementsByTagName("outline").length == 0) {outline = 1;}
        var aa = color.substr(0,2);
        var bb = color.substr(2,2);
        var gg = color.substr(4,2);
        var rr = color.substr(6,2);
        color = "#" + rr + gg + bb;

        var opacity = parseInt(aa,16)/256;
        if (!that.styles["#"+styleID]) {
          that.styles["#"+styleID] = {};
        }
        that.styles["#"+styleID].fillcolor=color;
        that.styles["#"+styleID].fillopacity=opacity;
        if (!fill) that.styles["#"+styleID].fillopacity = 0; 
        if (!outline) that.styles["#"+styleID].opacity = 0; 
      }
    }

    // Read through the Placemarks
    var placemarks = xmlDoc.documentElement.getElementsByTagName("Placemark");
    for (var i = 0; i < placemarks.length; i++) {
      var name=EGeoXml.value(placemarks[i].getElementsByTagName("name")[0]);
      var desc=EGeoXml.value(placemarks[i].getElementsByTagName("description")[0]);
      if (desc=="") {
        var desc=EGeoXml.value(placemarks[i].getElementsByTagName("text")[0]);
        desc = desc.replace(/\$\[name\]/,name);
        desc = desc.replace(/\$\[geDirections\]/,"");
      }
      if (desc.match(/^http:\/\//i)) {
        desc = '<a href="' + desc + '">' + desc + '</a>';
      }
      if (desc.match(/^https:\/\//i)) {
        desc = '<a href="' + desc + '">' + desc + '</a>';
      }
      var style=EGeoXml.value(placemarks[i].getElementsByTagName("styleUrl")[0]);
      var coords=GXml.value(placemarks[i].getElementsByTagName("coordinates")[0]);
      coords=coords.replace(/\s+/g," "); // tidy the whitespace
      coords=coords.replace(/^ /,"");    // remove possible leading whitespace
      coords=coords.replace(/ $/,"");    // remove possible trailing whitespace
      coords=coords.replace(/, /,",");   // tidy the commas
      var path = coords.split(" ");

      // Is this a polyline/polygon?
      if (path.length > 1) {
        // Build the list of points
        var points = [];
        var pbounds = new GLatLngBounds();
        for (var p=0; p<path.length; p++) {
          var bits = path[p].split(",");
          var point = new GLatLng(parseFloat(bits[1]),parseFloat(bits[0]));
          points.push(point);
          that.bounds.extend(point);
          pbounds.extend(point);
        }
        var linestring=placemarks[i].getElementsByTagName("LineString");
        if (linestring.length) {
          // it's a polyline grab the info from the style
          if (!!that.styles[style]) {
            var width = that.styles[style].width; 
            var color = that.styles[style].color; 
            var opacity = that.styles[style].opacity; 
          } else {
            var width = 5;
            var color = "#0000ff";
            var opacity = 0.45;
          }
          // Does the user have their own createmarker function?
          if (!!that.opts.createpolyline) {
            that.opts.createpolyline(points,color,width,opacity,pbounds,name,desc);
          } else {
            that.createPolyline(points,color,width,opacity,pbounds,name,desc);
          }
        }

        var polygons=placemarks[i].getElementsByTagName("Polygon");
        if (polygons.length) {
          // it's a polygon grab the info from the style
          if (!!that.styles[style]) {
            var width = that.styles[style].width; 
            var color = that.styles[style].color; 
            var opacity = that.styles[style].opacity; 
            var fillopacity = that.styles[style].fillopacity; 
            var fillcolor = that.styles[style].fillcolor; 
          } else {
            var width = 5;
            var color = "#0000ff";
            var opacity = 0.45;
            var fillopacity = 0.25;
            var fillcolor = "#0055ff";
          }
          // Does the user have their own createmarker function?
          if (!!that.opts.createpolygon) {
            that.opts.createpolygon(points,color,width,opacity,fillcolor,fillopacity,pbounds,name,desc);
          } else {
            that.createPolygon(points,color,width,opacity,fillcolor,fillopacity,pbounds,name,desc);
          }
        }


      } else {
        // It's not a poly, so I guess it must be a marker
        var bits = path[0].split(",");
        var point = new GLatLng(parseFloat(bits[1]),parseFloat(bits[0]));
        that.bounds.extend(point);
        // Does the user have their own createmarker function?
        if (!!that.opts.createmarker) {
          that.opts.createmarker(point, name, desc, style);
        } else {
          that.createMarker(point, name, desc, style);
        }
      }
    }
    
    // Scan through the Ground Overlays
    var grounds = xmlDoc.documentElement.getElementsByTagName("GroundOverlay");
    for (var i = 0; i < grounds.length; i++) {
      var url=EGeoXml.value(grounds[i].getElementsByTagName("href")[0]);
      var north=parseFloat(GXml.value(grounds[i].getElementsByTagName("north")[0]));
      var south=parseFloat(GXml.value(grounds[i].getElementsByTagName("south")[0]));
      var east=parseFloat(GXml.value(grounds[i].getElementsByTagName("east")[0]));
      var west=parseFloat(GXml.value(grounds[i].getElementsByTagName("west")[0]));
      var sw = new GLatLng(south,west);
      var ne = new GLatLng(north,east);                           
      var ground = new GGroundOverlay(url, new GLatLngBounds(sw,ne));
      that.bounds.extend(sw); 
      that.bounds.extend(ne); 
      that.groundoverlays.push(ground);
      that.map.addOverlay(ground);
    }

    // Is this the last file to be processed?
    that.progress--;
    if (that.progress == 0) {
      // Shall we zoom to the bounds?
      if (!that.opts.nozoom) {
        that.map.setZoom(that.map.getBoundsZoomLevel(that.bounds));
        that.map.setCenter(that.bounds.getCenter());
      }
      // Shall we display the sidebar?
      if (that.opts.sortbyname) {
        that.side_bar_list.sort();
      }
      if (that.opts.sidebarid) {
        for (var i=0; i<that.side_bar_list.length; i++) {
          var bits = that.side_bar_list[i].split("$$$",4);
          that.side_bar_html += that.sidebarfn(that.myvar,bits[0],bits[1],bits[2],bits[3]); 
        }
        document.getElementById(that.opts.sidebarid).innerHTML += that.side_bar_html;
      }
      if (that.opts.dropboxid) {
        for (var i=0; i<that.side_bar_list.length; i++) {
          var bits = that.side_bar_list[i].split("$$$",4);
          if (bits[1] == "marker") {
            that.side_bar_html += that.dropboxfn(that.myvar,bits[0],bits[1],bits[2],bits[3]); 
          }
        }
        document.getElementById(that.opts.dropboxid).innerHTML = '<select onChange="var I=this.value;if(I>-1){GEvent.trigger('+that.myvar+'.gmarkers[I],\'click\'); }">'
          + '<option selected> - Select a location - </option>'
          + that.side_bar_html
          + '</select>';
      }

      GEvent.trigger(that,"parsed");
    }
}

EGeoXml.prototype.hide = function() {
  for (var i=0; i<this.gmarkers.length; i++) {
    this.gmarkers[i].hide();
  }
  for (var i=0; i<this.gpolylines.length; i++) {
    this.gpolylines[i].hide();
  }
  for (var i=0; i<this.gpolygons.length; i++) {
    this.gpolygons[i].hide();
  }
  for (var i=0; i<this.groundoverlays.length; i++) {
    this.groundoverlays[i].hide();
  }
  if (this.opts.sidebarid) {
    document.getElementById(this.opts.sidebarid).style.display="none";
  }
  if (this.opts.dropboxid) {
    document.getElementById(this.opts.dropboxid).style.display="none";
  }
}

EGeoXml.prototype.show = function() {
  for (var i=0; i<this.gmarkers.length; i++) {
    this.gmarkers[i].show();
  }
  for (var i=0; i<this.gpolylines.length; i++) {
    this.gpolylines[i].show();
  }
  for (var i=0; i<this.gpolygons.length; i++) {
    this.gpolygons[i].show();
  }
  for (var i=0; i<this.groundoverlays.length; i++) {
    this.groundoverlays[i].show();
  }
  if (this.opts.sidebarid) {
    document.getElementById(this.opts.sidebarid).style.display="";
  }
  if (this.opts.dropboxid) {
    document.getElementById(this.opts.dropboxid).style.display="";
  }
}

// BEGIN static/javascript/libs/epoly.js
/*********************************************************************\
*                                                                     *
* epolys.js                                          by Mike Williams *
*                                                                     *
* A Google Maps API Extension                                         *
*                                                                     *
* Adds various Methods to GPolygon and GPolyline                      *
*                                                                     *
* .Contains(latlng) returns true is the poly contains the specified   *
*                   GLatLng                                           *
*                                                                     *
* .Area()           returns the approximate area of a poly that is    *
*                   not self-intersecting                             *
*                                                                     *
* .Distance()       returns the length of the poly path               *
*                                                                     *
* .Bounds()         returns a GLatLngBounds that bounds the poly      *
*                                                                     *
* .GetPointAtDistance() returns a GLatLng at the specified distance   *
*                   along the path.                                   *
*                   The distance is specified in metres               *
*                   Reurns null if the path is shorter than that      *
*                                                                     *
* .GetPointsAtDistance() returns an array of GLatLngs at the          *
*                   specified interval along the path.                *
*                   The distance is specified in metres               *
*                                                                     *
* .GetIndexAtDistance() returns the vertex number at the specified    *
*                   distance along the path.                          *
*                   The distance is specified in metres               *
*                   Reurns null if the path is shorter than that      *
*                                                                     *
* .Bearing(v1?,v2?) returns the bearing between two vertices          *
*                   if v1 is null, returns bearing from first to last *
*                   if v2 is null, returns bearing from v1 to next    *
*                                                                     *
*                                                                     *
***********************************************************************
*                                                                     *
*   This Javascript is provided by Mike Williams                      *
*   Community Church Javascript Team                                  *
*   http://www.bisphamchurch.org.uk/                                  *
*   http://econym.org.uk/gmap/                                        *
*                                                                     *
*   This work is licenced under a Creative Commons Licence            *
*   http://creativecommons.org/licenses/by/2.0/uk/                    *
*                                                                     *
***********************************************************************
*                                                                     *
* Version 1.1       6-Jun-2007                                        *
* Version 1.2       1-Jul-2007 - fix: Bounds was omitting vertex zero *
*                                add: Bearing                         *
* Version 1.3       28-Nov-2008  add: GetPointsAtDistance()           *
* Version 1.4       12-Jan-2009  fix: GetPointsAtDistance()           *
*                                                                     *
\*********************************************************************/


// === A method for testing if a point is inside a polygon
// === Returns true if poly contains point
// === Algorithm shamelessly stolen from http://alienryderflex.com/polygon/ 
GPolygon.prototype.Contains = function(point) {
  var j=0;
  var oddNodes = false;
  var x = point.lng();
  var y = point.lat();
  for (var i=0; i < this.getVertexCount(); i++) {
    j++;
    if (j == this.getVertexCount()) {j = 0;}
    if (((this.getVertex(i).lat() < y) && (this.getVertex(j).lat() >= y))
    || ((this.getVertex(j).lat() < y) && (this.getVertex(i).lat() >= y))) {
      if ( this.getVertex(i).lng() + (y - this.getVertex(i).lat())
      /  (this.getVertex(j).lat()-this.getVertex(i).lat())
      *  (this.getVertex(j).lng() - this.getVertex(i).lng())<x ) {
        oddNodes = !oddNodes
      }
    }
  }
  return oddNodes;
}

// === A method which returns the approximate area of a non-intersecting polygon in square metres ===
// === It doesn't fully account for spechical geometry, so will be inaccurate for large polygons ===
// === The polygon must not intersect itself ===
GPolygon.prototype.Area = function() {
  var a = 0;
  var j = 0;
  var b = this.Bounds();
  var x0 = b.getSouthWest().lng();
  var y0 = b.getSouthWest().lat();
  for (var i=0; i < this.getVertexCount(); i++) {
    j++;
    if (j == this.getVertexCount()) {j = 0;}
    var x1 = this.getVertex(i).distanceFrom(new GLatLng(this.getVertex(i).lat(),x0));
    var x2 = this.getVertex(j).distanceFrom(new GLatLng(this.getVertex(j).lat(),x0));
    var y1 = this.getVertex(i).distanceFrom(new GLatLng(y0,this.getVertex(i).lng()));
    var y2 = this.getVertex(j).distanceFrom(new GLatLng(y0,this.getVertex(j).lng()));
    a += x1*y2 - x2*y1;
  }
  return Math.abs(a * 0.5);
}

// === A method which returns the length of a path in metres ===
GPolygon.prototype.Distance = function() {
  var dist = 0;
  for (var i=1; i < this.getVertexCount(); i++) {
    dist += this.getVertex(i).distanceFrom(this.getVertex(i-1));
  }
  return dist;
}

// === A method which returns the bounds as a GLatLngBounds ===
GPolygon.prototype.Bounds = function() {
  var bounds = new GLatLngBounds();
  for (var i=0; i < this.getVertexCount(); i++) {
    bounds.extend(this.getVertex(i));
  }
  return bounds;
}

// === A method which returns a GLatLng of a point a given distance along the path ===
// === Returns null if the path is shorter than the specified distance ===
GPolygon.prototype.GetPointAtDistance = function(metres) {
  // some awkward special cases
  if (metres == 0) return this.getVertex(0);
  if (metres < 0) return null;
  var dist=0;
  var olddist=0;
  for (var i=1; (i < this.getVertexCount() && dist < metres); i++) {
    olddist = dist;
    dist += this.getVertex(i).distanceFrom(this.getVertex(i-1));
  }
  if (dist < metres) {return null;}
  var p1= this.getVertex(i-2);
  var p2= this.getVertex(i-1);
  var m = (metres-olddist)/(dist-olddist);
  return new GLatLng( p1.lat() + (p2.lat()-p1.lat())*m, p1.lng() + (p2.lng()-p1.lng())*m);
}

// === A method which returns an array of GLatLngs of points a given interval along the path ===
GPolygon.prototype.GetPointsAtDistance = function(metres) {
  var next = metres;
  var points = [];
  // some awkward special cases
  if (metres <= 0) return points;
  var dist=0;
  var olddist=0;
  for (var i=1; (i < this.getVertexCount()); i++) {
    olddist = dist;
    dist += this.getVertex(i).distanceFrom(this.getVertex(i-1));
    while (dist > next) {
      var p1= this.getVertex(i-1);
      var p2= this.getVertex(i);
      var m = (next-olddist)/(dist-olddist);
      points.push(new GLatLng( p1.lat() + (p2.lat()-p1.lat())*m, p1.lng() + (p2.lng()-p1.lng())*m));
      next += metres;    
    }
  }
  return points;
}

// === A method which returns the Vertex number at a given distance along the path ===
// === Returns null if the path is shorter than the specified distance ===
GPolygon.prototype.GetIndexAtDistance = function(metres) {
  // some awkward special cases
  if (metres == 0) return this.getVertex(0);
  if (metres < 0) return null;
  var dist=0;
  var olddist=0;
  for (var i=1; (i < this.getVertexCount() && dist < metres); i++) {
    olddist = dist;
    dist += this.getVertex(i).distanceFrom(this.getVertex(i-1));
  }
  if (dist < metres) {return null;}
  return i;
}

// === A function which returns the bearing between two vertices in decgrees from 0 to 360===
// === If v1 is null, it returns the bearing between the first and last vertex ===
// === If v1 is present but v2 is null, returns the bearing from v1 to the next vertex ===
// === If either vertex is out of range, returns void ===
GPolygon.prototype.Bearing = function(v1,v2) {
  if (v1 == null) {
    v1 = 0;
    v2 = this.getVertexCount()-1;
  } else if (v2 ==  null) {
    v2 = v1+1;
  }
  if ((v1 < 0) || (v1 >= this.getVertexCount()) || (v2 < 0) || (v2 >= this.getVertexCount())) {
    return;
  }
  var from = this.getVertex(v1);
  var to = this.getVertex(v2);
  if (from.equals(to)) {
    return 0;
  }
  var lat1 = from.latRadians();
  var lon1 = from.lngRadians();
  var lat2 = to.latRadians();
  var lon2 = to.lngRadians();
  var angle = - Math.atan2( Math.sin( lon1 - lon2 ) * Math.cos( lat2 ), Math.cos( lat1 ) * Math.sin( lat2 ) - Math.sin( lat1 ) * Math.cos( lat2 ) * Math.cos( lon1 - lon2 ) );
  if ( angle < 0.0 ) angle  += Math.PI * 2.0;
  angle = angle * 180.0 / Math.PI;
  return parseFloat(angle.toFixed(1));
}




// === Copy all the above functions to GPolyline ===
GPolyline.prototype.Contains             = GPolygon.prototype.Contains;
GPolyline.prototype.Area                 = GPolygon.prototype.Area;
GPolyline.prototype.Distance             = GPolygon.prototype.Distance;
GPolyline.prototype.Bounds               = GPolygon.prototype.Bounds;
GPolyline.prototype.GetPointAtDistance   = GPolygon.prototype.GetPointAtDistance;
GPolyline.prototype.GetPointsAtDistance  = GPolygon.prototype.GetPointsAtDistance;
GPolyline.prototype.GetIndexAtDistance   = GPolygon.prototype.GetIndexAtDistance;
GPolyline.prototype.Bearing              = GPolygon.prototype.Bearing;





// BEGIN static/javascript/vantrash/map.js
(function($) {
TrashMap = function(opts) {
    if (!arguments.length) opts = {};
    $.extend(this, opts);
}

TrashMap.prototype = {
    monthNames: [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
    ],
    descriptions: {},
    center: function() {
        return new GLatLng(49.26422, -123.138542);
    },

    showSchedule: function(node, name, color) {
        var self = this;

        $.getJSON('/zones/' + name + '/nextpickup.json', function (next) {
            var yard = '';
            next = next.next[0];
            if (next.match(/^\d+-(\d+)-(\d+)(?: (Y))?/)) {
                next = self.monthNames[RegExp.$1 - 1] + ' ' + RegExp.$2;
                yard = RegExp.$3
                    ? ' (Yard trimmings will be picked up)'
                    : ' (Yard trimmings will NOT be picked up)'
            }

            $.getJSON('/zones/' + name + '/pickupdays.json', function (days) {
                var $div = $(Jemplate.process('balloon.tt2', {
                    description: self.descriptions[name],
                    next: next,
                    yard: yard
                }));

                if (!node) throw new Error("Node required");
                if (node.openInfoWindow) {
                    node.openInfoWindow($div.get(0), {maxWidth: 220});
                }
                else {
                    var center = node.getBounds().getCenter();
                    self.map.openInfoWindow(
                        center, $div.get(0), {maxWidth: 220}
                    );
                }
                
                $div.find('.subscribe', node).button();

                /* Make a hash of days */
                var pickupdays = {};
                var yarddays = {};
                $.each(days, function(i,d) {
                    var key = [d.year,Number(d.month),Number(d.day)].join('-');
                    pickupdays[key] = true;
                    if (d.flags == 'Y') {
                        yarddays[key] = true
                    }
                });

                $div.find('.calendar', node).datepicker({
                    beforeShowDay: function(day) {
                        var key = [
                            day.getFullYear(), day.getMonth()+1, day.getDate()
                        ].join('-');
                        return [
                            false, // Not selectable
                            pickupdays[key] ? 'marked' : '', // class

                            // title XXX NOT GOOD ENOUGH
                            yarddays[key] ? 'Yard trimmings are picked up' : ''
                        ];
                    },
                    beforeShow: function(input, inst) {
                        console.log('show', input);
                    }
                });
            });
        });
    },

    createMap: function(node) {
        this.map = new GMap2(node);
        this.map.setCenter(this.center(),9);
        this.map.setUIToDefault();
    },

    render: function(node) {
        var self = this;
        this.createMap(node);
        this.loadKML(function() {
            if (self.startingZone) {
                self.showScheduleForZone(self.startingZone);
            }
            else {
                self.showScheduleForCurrentLocation();
            }
        });
    },

    showScheduleForZone: function(zone_name) {
        var self = this;
        var matchedZone;
        $.each(this.zones, function(i,zone) {
            if (zone.name == zone_name) {
                matchedZone = zone;
            }
        });
        if (matchedZone) {
            self.showSchedule(matchedZone, matchedZone.name, matchedZone.color);
        }
        else {
            throw new Error("Can't find zone!");
        }
    },

    showScheduleForLocation: function (latlng) {
        var zone = this.containingZone(latlng);
        if (zone) {
            if (this.marker) this.map.removeOverlay(this.marker);
            this.marker = new GMarker(latlng, {
                icon: this.createHomeIcon()
            });
            this.map.addOverlay(this.marker);
            this.map.setCenter(latlng);

            this.showSchedule(this.marker, zone.name, zone.color);
        }
    },

    containingZone: function (latlng) {
        var containingZone;

        $.each(this.zones, function(i,zone) {
            if (zone.Contains(latlng)) {
                containingZone = zone;
            }
        });
        return containingZone;
    },

    showScheduleForCurrentLocation: function () {
        var self = this;
        this.findCurrentLocation(function(lat, lng) {
            var latlng = new GLatLng(lat, lng);
            self.showScheduleForLocation(latlng);
        });
    },

    findCurrentLocation: function (callback) {
        var self = this;
        
        // Try W3C Geolocation (Preferred)
        if (navigator.geolocation) {
            navigator.geolocation.watchPosition(
                function(position) {
                    callback(
                        position.coords.latitude, position.coords.longitude
                    );
                }, function() {
                    // error
                }
            );
        }
        // Try Google Gears Geolocation
        else if (google.gears) {
            var geo = google.gears.factory.create('beta.geolocation');
            geo.getCurrentPosition(
                function(position) {
                    callback(position.latitude,position.longitude);
                }, function() {
                    // error
                }
            );
        }
        // Browser doesn't support Geolocation
        else {

        }
    },

    loadKML: function(callback) {
        var self = this;
        this.zones = [];
        this.exml = new EGeoXml("exml", this.map, "/zones.kml", {
            createpolygon: function (pts,sc,sw,so,fc,fo,pl,name,desc) {
                var zone = new GPolygon(pts, sc, sw, so, fc, fo);
                GEvent.addListener(zone, 'click', function() {
                    self.showSchedule(zone, name, fc);
                    return false;
                });
                zone.name = name;
                self.descriptions[name] = desc;
                self.zones.push(zone);
                self.map.addOverlay(zone);
            }
        });
        GEvent.addListener(this.exml, 'parsed', function() {
            self.bounds = self.map.getBounds();
            if ($.isFunction(callback)) { callback() };
        });
        this.exml.parse();
    },

   /* Google Map Custom Marker Maker 2009
    * Please include the following credit in your code
    *
    * Sample custom marker code created with Google Map Custom Marker Maker
    * http://www.powerhut.co.uk/googlemaps/custom_markers.php
    */
    createHomeIcon: function() {
        var myIcon = new GIcon();
        var myIcon = new GIcon();
        myIcon.image = '/images/homeIcon.png';
        myIcon.printImage = '/images/homeIconPrint.gif';
        myIcon.mozPrintImage = '/images/homeIconMozPrint.gif';
        myIcon.iconSize = new GSize(20,20);
        myIcon.shadow = '/images/homeIconShadow.png';
        myIcon.transparent = '/images/homeIconTransparent.png';
        myIcon.shadowSize = new GSize(30,20);
        myIcon.printShadow = '/images/homeIconPrintShadow.gif';
        myIcon.iconAnchor = new GPoint(10,20);
        myIcon.infoWindowAnchor = new GPoint(10,0);
        myIcon.imageMap = [15,0,15,1,15,2,15,3,15,4,16,5,17,6,18,7,19,8,19,9,16,10,16,11,16,12,16,13,16,14,16,15,16,16,16,17,16,18,3,18,3,17,3,16,3,15,3,14,3,13,3,12,3,11,3,10,0,9,0,8,1,7,2,6,3,5,5,4,6,3,7,2,8,1,9,0];
        return myIcon;
    },

    search: function(address) {
        var self = this;
        if (!this.bounds) return;
        if (!address.match(/vancouver/i)) address += ', Vancouver';
        var geocoder = new GClientGeocoder();
        geocoder.setViewport(this.map.getBounds());
        geocoder.setBaseCountryCode('ca');
        geocoder.getLatLng(address, function(point) {
            if (! point) {
                alert("Not found");
            }
            else {
                if (self.bounds.contains(point)) {
                    self.showScheduleForLocation(point);
                }
                else {
                    alert("Sorry, I couldn't find that address within this map view. Please try again"); 
                }
            }
        });
    },

    logClicks: function() {
        $('body').append(
            $('<a href="#">clear</a>')
                .click(function() { $('#clicks').empty() })
        );
        $('body').append('<div id="clicks"></div>');
        GEvent.addListener(this.map, 'click', function(o, latlng) {
            if (latlng) {
                $('#clicks').append(latlng.x+', '+latlng.y+', 0<br/>');
            }
        });
    }
}

})(jQuery);
