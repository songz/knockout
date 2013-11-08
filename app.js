// ***
// *** Required modules
// ***
var express = require('express');
var OpenTokLibrary = require('opentok');
var Firebase = require('firebase');

// ***
// *** OpenTok Constants for creating Session and Token values
// ***
var OTKEY = process.env.TB_KEY;
var OTSECRET = process.env.TB_SECRET;
var OpenTokObject = new OpenTokLibrary.OpenTokSDK(OTKEY, OTSECRET);

// ***
// *** Setup Express to handle static files in public folder
// *** Express is also great for handling url routing
// ***
var app = express();
app.use(express.static(__dirname + '/public'));
app.set( 'views', __dirname + "/views");
app.set( 'view engine', 'ejs' );

// ***
// *** When user goes to root directory, render index page
// ***
app.get("/", function( req, res ){
  // make sure that we are always in https
  res.render( 'index' );
});

app.get("/:rid", function( req, res ){
  // find request format, json or html?
  var path = req.params.rid.split(".json");
  var rid = path[0];

  var myRootRef = new Firebase("https://nodeknockout.firebaseIO.com/"+rid)
  myRootRef.once( "value", function( snapshot ){
    var info = snapshot.val();
    console.log( info );
    if( info.sid && info.sid.length > 3 ){
      returnRoomResponse( res, { rid: rid, sid: info.sid }, path[1]);
    }else{
      console.log(" no session id found ");
      OpenTokObject.createSession(function(sessionId){
        myRootRef.child( "sid" ).set( sessionId, function(){
          returnRoomResponse( res, { rid: rid, sid: sessionId }, path[1]);
        });
      });
    }
  });
});

function returnRoomResponse( res, data, json ){
  data.apiKey = OTKEY;
  data.token = OpenTokObject.generateToken( {session_id: data.sid, role:OpenTokLibrary.RoleConstants.MODERATOR} );
  if( json == "" ){
    res.json( data );
  }else{
    res.render( 'room', data );
  }
}

// ***
// *** start server, listen to port (predefined or 9393)
// ***
var port = process.env.PORT || 5000;
app.listen(port);
