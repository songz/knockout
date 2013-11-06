window.onresize = ->
  ResizeLayoutContainer()

class User
  constructor: (@rid, @apiKey, @sid, @token) ->
    # templates
    @messageTemplate = Handlebars.compile( $("#messageTemplate").html() )
    @userStreamTemplate = Handlebars.compile( $("#userStreamTemplate").html() )
    @notifyTemplate = Handlebars.compile( $("#notifyTemplate").html() )
    @myRootRef = new Firebase("https://nodeknockout.firebaseIO.com/#{@rid}")
    @myRootRef.once 'value', (dataSnapshot) =>
      @roomData = dataSnapshot.val()
      $(".titleText").text( @roomData.name )
    @presenceRef = new Firebase("https://nodeknockout.firebaseIO.com/#{@rid}/users")
    @presenceRef.once "value", (snap) =>
      console.log "presenceRef callback"
      con = @presenceRef.push( true )
      con.onDisconnect().remove()
      window.setInterval =>
        console.log "setting priority"
        @myRootRef.setPriority( -Date.now() )
      , 60000

    # variables
    @initialized = false
    @chatData = []
    @filterData = {}
    @allUsers = {}
    @streams = {}
    @subscribers = {}
    @printCommands() # welcome users into the room

    # set up OpenTok
    @publisher = TB.initPublisher( @apiKey, "myPublisher", {width:240, height:190} )
    @session = TB.initSession( @sid )
    @session.on( "sessionConnected", @sessionConnectedHandler )
    @session.on( "sessionDisconnected", @sessionDisconnectedHandler )
    @session.on( "streamCreated", @streamCreatedHandler )
    @session.on( "streamDestroyed", @streamDestroyedHandler )
    @session.on( "connectionCreated", @connectionCreatedHandler )
    @session.on( "connectionDestroyed", @connectionDestroyedHandler )
    @session.on( "signal:initialize", @signalInitializeHandler )
    @session.on( "signal:chat", @signalChatHandler )
    @session.on( "signal:filter", @signalFilterHandler )
    @session.on( "signal:name", @signalNameHandler )
    @session.connect( @apiKey, @token )

    # add event listeners
    self = @
    $(".roomOption").click ->
      if !$(@).hasClass("readyOption") then return
      if $(@).hasClass("publishOption") and $(@).hasClass("optionSelected")
        self.session.unpublish self.publisher
        $(@).removeClass( "readyOption" )
      if $(@).hasClass("publishOption") and !$(@).hasClass("optionSelected")
        self.session.publish self.publisher
        $(@).removeClass( "readyOption" )
      if $(@).hasClass("textOption") and !$(@).hasClass("optionSelected")
        for k,v of self.subscribers
          self.removeStream( v.stream.connection.connectionId )
          self.session.unsubscribe v
        console.log "finished unsubscribing"
        $(@).addClass( "optionSelected" )
        ResizeLayoutContainer()
        return
      if $(@).hasClass("textOption") and $(@).hasClass("optionSelected")
        $(@).removeClass( "optionSelected" ) #careful, order matters
        for k,v of self.streams
          self.createSubscriber( v )
        ResizeLayoutContainer()
        return
      if $(@).hasClass("audioOption") and !$(@).hasClass("optionSelected")
        # user decided to go audio only
        for k,v of self.subscribers
          v.subscribeToVideo( false )
        $(@).addClass( "optionSelected" )
        return
      if $(@).hasClass("audioOption") and $(@).hasClass("optionSelected")
        # user decided to turn off audio only
        for k,v of self.subscribers
          v.subscribeToVideo( true )
        $(@).removeClass( "optionSelected" )
        return

    $(".filterOption").click ->
      $(".filterOption").removeClass("optionSelected")
      prop = $(@).data('value')
      self.applyClassFilter( prop, "#myPublisher" )
      $(@).addClass("optionSelected")
      self.session.signal( {type: "filter", data: {cid: self.session.connection.connectionId, filter: prop }}, self.errorSignal )
      self.filterData[self.session.connection.connectionId] = prop
    $('#messageInput').keypress @inputKeypress

  # session and signaling events
  sessionConnectedHandler: (event) =>
    $(".audioOption").addClass( "readyOption" )
    $(".textOption").addClass( "readyOption" )
    console.log "session connected"
    @subscribeStreams(event.streams)
    @session.publish( @publisher )
    ResizeLayoutContainer()

    @myConnectionId = @session.connection.connectionId
    @name = "Guest-#{@myConnectionId.substring( @myConnectionId.length - 8, @myConnectionId.length )}"
    @allUsers[ @myConnectionId ] = @name
    $("#messageInput").removeAttr( "disabled" )
    $('#messageInput').focus()
  sessionDisconnectedHandler: (event) =>
    console.log event.reason
    if( event.reason == "forceDisconnected" )
      alert "Someone in the room found you offensive and removed you. Please evaluate your behavior"
    else
      alert "You have been disconnected! Please try again"
    window.location = "/"
  streamCreatedHandler: (event) =>
    $(".audioOption").addClass( "readyOption" )
    $(".textOption").addClass( "readyOption" )
    @subscribeStreams(event.streams)
    ResizeLayoutContainer()
  streamDestroyedHandler: (event) =>
    for stream in event.streams
      if @session.connection.connectionId == stream.connection.connectionId
        $(".publishOption").removeClass( "optionSelected" )
        $(".publishOption").addClass( "readyOption" )
        event.preventDefault()
      else
        delete @streams[ stream.connection.connectionId ]
        delete @subscribers[ stream.connection.connectionId ]
        @removeStream( stream.connection.connectionId )
    ResizeLayoutContainer()
  connectionCreatedHandler: ( event ) =>
    console.log "new connection created"
    cid = "#{event.connections[0].id}"
    guestName = "Guest-#{cid.substring( cid.length - 8, cid.length )}"
    console.log "signaling over!"
    console.log @allUsers
    @session.signal( { type: "initialize", to: event.connections, data: {chat: @chatData, filter: @filterData, users: @allUsers, random:[1,2,3]}}, @errorSignal )
    @allUsers[cid] = guestName
    @writeChatData( {name: @name, text:"/serv #{guestName} has joined the room"  } )
    console.log "signal new connection room info"
  connectionDestroyedHandler: ( event ) =>
    cid = "#{event.connections[0].id}"
    @writeChatData( {name: @name, text:"/serv #{@allUsers[cid]} has left the room"  } )
    delete @allUsers[cid]
  signalInitializeHandler: ( event ) =>
    console.log "initialize handler"
    console.log event.data
    if @initialized then return
    for k,v of event.data.users
      @allUsers[k] = v
    for k,v of event.data.filter
      @filterData[k] = v
    for e in event.data.chat
      @writeChatData( e )
    @initialized = true
  signalChatHandler: ( event ) =>
    @writeChatData( event.data )
  signalFilterHandler: ( event ) =>
    val = event.data
    console.log "filter received"
    @applyClassFilter( val.filter, ".stream#{val.cid}" )
  signalNameHandler: ( event ) =>
    console.log "name signal received"
    console.log event.data
    @allUsers[ event.data[0] ] = event.data[1]

  # events
  inputKeypress: (e) =>
    msgData = {}
    if (e.keyCode == 13)
      text = $('#messageInput').val().trim()
      if text.length < 1 then return
      parts = text.split(' ')
      if parts[0] == "/help"
        @printCommands()
        $('#messageInput').val('')
        return
      if parts[0] == "/list"
        @displayChatMessage( @notifyTemplate( {message: "-----------"} ) )
        @displayChatMessage( @notifyTemplate( {message: "Users currently in the room"} ) )
        for k,v of @allUsers
          @displayChatMessage( @notifyTemplate( {message: "- #{v}" } ) )
        @displayChatMessage( @notifyTemplate( {message: "-----------"} ) )
        $('#messageInput').val('')
        return
      if parts[0] == "/name" or parts[0] == "/nick"
        for k, v of @allUsers
          if v == parts[1] or parts[1].length <= 2
            alert("Sorry, but that name has already been taken or is too short.")
            return
        msgData = {name: parts[1], text: "/serv #{@name} is now known as #{parts[1]}"}
        @session.signal( {type: "name", data: [@myConnectionId, parts[1]]}, @errorSignal )
        @name = parts[1]
      else
        msgData = {name: @name, text: text}
      $('#messageInput').val('')
      @session.signal( {type: "chat", data: msgData}, @errorSignal )

  # helpers
  errorSignal: (error) =>
    if (error)
      console.log("signal error: " + error.reason)
  applyClassFilter: (prop, selector) =>
    if prop
      $(selector).removeClass( "Blur Sepia Grayscale Invert" )
      $(selector).addClass( prop )
      console.log "applyclassfilter..."+prop
  removeStream: (cid) =>
    element$ = $(".stream#{cid}")
    if element$ then element$.remove()
  createSubscriber: (stream) =>
    if $(".textOption").hasClass('optionSelected') then return
    streamConnectionId = stream.connection.connectionId
    divId = "stream#{streamConnectionId}"
    $("#streams_container").append( @userStreamTemplate({ id: divId }) )
    prop = {width:240, height:190}
    prop.subscribeToVideo = if $(".audioOption").hasClass('optionSelected') then false else true
    @subscribers[ streamConnectionId ] = @session.subscribe( stream, divId , prop )
    @applyClassFilter( @filterData[ streamConnectionId ], ".stream#{streamConnectionId}" )

    # bindings to mark offensive users
    divId$ = $(".#{divId}")
    divId$.mouseenter ->
      $(@).find('.flagUser').show()
    divId$.mouseleave ->
      $(@).find('.flagUser').hide()

    # mark user as offensive
    self = @
    divId$.find('.flagUser').click ->
      streamConnection = $(@).data('streamconnection')
      if confirm("Is this user being inappropriate? If so, we are sorry that you had to go through that. Click confirm to remove user")
        self.applyClassFilter("Blur", ".#{streamConnection}")
        self.session.forceDisconnect( streamConnection.split("stream")[1] )
  subscribeStreams: (streams) =>
    for stream in streams
      streamConnectionId = stream.connection.connectionId
      if @session.connection.connectionId == streamConnectionId
        $(".publishOption").addClass( "optionSelected" )
        $(".publishOption").addClass( "readyOption" )
      else
        # create new div container for stream, subscribe, apply filter
        @createSubscriber( stream )
        @streams[ streamConnectionId ] = stream
  writeChatData: (val) =>
    @chatData.push( {name: val.name, text: unescape(val.text) } )
    text = val.text.split(' ')
    if text[0] == "/serv"
      @displayChatMessage( @notifyTemplate( {message: val.text.split("/serv")[1] } ) )
      return
    message = ""
    urlRegex = /(https?:\/\/)?([\da-z\.-]+)\.([a-z]{2,6})(\/.*)?$/g
    for e in text
      if e.length<2000 and e.match( urlRegex ) and e.split("..").length < 2 and e[e.length-1] != "."
        message += e.replace( urlRegex,"<a href='http://$2.$3$4' target='_blank'>$1$2.$3$4<a>" )+" "
      else
        message += Handlebars.Utils.escapeExpression(e) + " "
    val.text = message
    @displayChatMessage( @messageTemplate( val ) )
  displayChatMessage: (message)->
    $("#displayChat").append message
    $('#displayChat')[0].scrollTop = $('#displayChat')[0].scrollHeight
  printCommands: ->
    @displayChatMessage( @notifyTemplate( {message: "-----------"} ) )
    @displayChatMessage( @notifyTemplate( {message: "Welcome to Knockout Chat."} ) )
    @displayChatMessage( @notifyTemplate( {message: "Type /nick your_name to change your name"} ) )
    @displayChatMessage( @notifyTemplate( {message: "Type /list to see list of users in the room"} ) )
    @displayChatMessage( @notifyTemplate( {message: "Type /help to see a list of commands"} ) )
    @displayChatMessage( @notifyTemplate( {message: "-----------"} ) )
window.User = User
