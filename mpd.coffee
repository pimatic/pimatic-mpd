module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  mpd = require "mpd"
  Promise.promisifyAll(mpd.prototype)


  # ###MpdPlugin class
  class MpdPlugin extends env.plugins.Plugin


    init: (app, @framework, @config) ->

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("MpdPlayer", {
        configDef: deviceConfigDef.MpdPlayer, 
        createCallback: (config) => new MpdPlayer(config)
      })

      #client.on("system", (name) -> console.log "update", name )

  class MpdPlayer extends env.devices.Device
    _state: null
    _currentTitle: null
    _currentArtist: null

    actions: 
      play:
        description: "starts playing"
      pause:
        description: "pauses playing"
      next:
        description: "play next song"
      previous:
        description: "play previous song"

    attributes:
      currentArtist:
        description: "the current playing track artist"
        type: "string"   
      currentTitle:
        description: "the current playing track title"
        type: "string"
      state:
        description: "the current state of the player"
        type: "string"

    template: "musicplayer"

    constructor: (@config) ->
      @name = config.name
      @id = config.id

      @_client = mpd.connect(
        port: @config.port
        host: @config.host      
      )

      @_connectionPromise = new Promise( (resolve) =>
        @_client.once("ready", => 
          console.log "ready"
          resolve()
        )
      ).timeout(20000)

      @_connectionPromise.then( => @_updateInfo() ).catch( (error) =>
        env.logger.error(error)
      )

      @_client.on("system-player", =>
        return @_updateInfo().catch( (err) =>
          env.logger.error "Error sending mpd command: #{err}"
          env.logger.debug err
        )
      )

      super()

    getState: () ->
      return Promise.resolve @_state

    getCurrentTitle: () -> Promise.resolve(@_currentTitle)
    getCurrentArtist: () -> Promise.resolve(@_currentTitle)
    play: () -> @_sendCommandAction('pause', '0')
    pause: () -> @_sendCommandAction('pause', '1')
    previous: () -> @_sendCommandAction('previous')
    next: () -> @_sendCommandAction('next')

    _updateInfo: -> Promise.all([@_getStatus(), @_getCurrentSong()])

    _setState: (state) ->
      if @_state isnt state
        @_state = state
        @emit 'state', state

    _setCurrentTitle: (title) ->
      if @_currentTitle isnt title
        @_currentTitle = title
        @emit 'currentTitle', title

    _setCurrentArtist: (artist) ->
      if @_currentArtist isnt artist
        @_currentArtist = artist
        @emit 'currentArtist', artist

    _getStatus: () ->
      @_client.sendCommandAsync(mpd.cmd("status", [])).then( (msg) =>
        info = mpd.parseKeyValueMessage(msg)
        @_setState(info.state)
        #if info.songid isnt @_currentTrackId
      )

    _getCurrentSong: () ->
      @_client.sendCommandAsync(mpd.cmd("currentsong", [])).then( (msg) =>
        info = mpd.parseKeyValueMessage(msg)
        @_setCurrentTitle(if info.Title? then info.Title else "")
        @_setCurrentArtist(if info.Name? then info.Name else "")
      ).catch( (err) =>
        env.logger.error "Error sending mpd command: #{err}"
        env.logger.debug err
      )

    _sendCommandAction: (action, args...) ->
      return @_connectionPromise.then( =>
        return @_client.sendCommandAsync(mpd.cmd(action, args)).then( (msg) =>
          return
        )
      )

  # ###Finally
  # Create a instance of my plugin
  mpdPlugin = new MpdPlugin
  # and return it to the framework.
  return mpdPlugin