$("#roomName").focus()

goToRoom = ->
  roomName = $("#roomName").val().trim()
  if roomName.length <= 0
    alert "Room Name is Invalid"
    return
  $("#roomContainer").fadeOut('slow')
  window.location = "/#{roomName}"

$('#submitRoomButton').click ->
  # validate input
  roomName = $("#roomName").val()
  roomDescription = $("#roomDescription").val()
  roomId = "#{Date.now()%10000000}#{Math.floor(Math.random()*10000)}"
  myRootRef.child( roomId ).set {name: roomName, description: roomDescription}, ->
    window.location = "/#{roomId}"

$('#roomName').keypress (e) ->
  if (e.keyCode == 13)
    goToRoom()

verticalCenter = ->
  mtop = (window.innerHeight - $("#insideContainer").outerHeight())/2
  $("#insideContainer").css({"margin-top": "#{mtop}px"})

  #window.onresize = verticalCenter

#verticalCenter()


roomTemplate = Handlebars.compile( $("#roomTemplate").html() )

myRootRef = new Firebase('https://nodeknockout.firebaseIO.com/')
myRootRef.once 'value', (dataSnapshot) ->
  for k,v of dataSnapshot.val()
    v.url = "/#{k}"
    $("#roomsContainer").append roomTemplate( v )
