$("#searchRoom").focus()

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
  if roomName.length < 3 or roomDescription.length < 3 or roomName.length > 100 or roomDescription.length > 200
    alert "Invalid Room Name or Room Description. Max number of characters for room name is 100 characters, for room description is 200 characters"
    return
  roomId = "#{Date.now()%10000000}#{Math.floor(Math.random()*10000)}"
  myRootRef.child( roomId ).setWithPriority {name: roomName, description: roomDescription}, -Date.now(), ->
    window.location = "/#{roomId}"

$('#searchRoom').keyup (e) ->
  if $(@).val().length > 0
    $(".roomInformation").hide()
    $(".roomInformation[data-info*=#{$(@).val()}]").show()
    return
  $(".roomInformation").show()

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
    v.usersCount = if v.users then Object.keys( v.users ).length else 0
    $("#roomsContainer").append roomTemplate( v )
