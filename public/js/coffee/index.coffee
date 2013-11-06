$("#searchRoom").focus()

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
  val = $(@).val().toLowerCase()
  if val.length > 0
    $(".roomInformation").hide()
    $(".roomInformation[data-info*='#{val}']").show()
    return
  $(".roomInformation").show()


roomTemplate = Handlebars.compile( $("#roomTemplate").html() )

generateRoom = (childSnapshot) ->
  v = childSnapshot.val()
  v.url = "/#{childSnapshot.name()}"
  v.key = childSnapshot.name()
  v.usersCount = if v.users then Object.keys( v.users ).length else 0
  $("#roomsContainer").append roomTemplate( v )

myRootRef = new Firebase('https://nodeknockout.firebaseIO.com/')
myRootRef.on 'child_added', (dataSnapshot) ->
  generateRoom( dataSnapshot )
myRootRef.on 'child_removed', (dataSnapshot) ->
  $("##{dataSnapshot.name()}").remove()

Handlebars.registerHelper "lower", (options) ->
  return options.fn(this).toLowerCase()

$('#myModal').on 'shown.bs.modal', (e) ->
  console.log "modal appears"
  $("#roomName").focus()
