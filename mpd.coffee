module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  M = env.matcher
  _ = env.require('lodash')

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

      @framework.ruleManager.addActionProvider(new mpdPauseActionProvider(@framework))
      @framework.ruleManager.addActionProvider(new mpdPlayActionProvider(@framework))
      @framework.ruleManager.addActionProvider(new mpdVolumeActionProvider(@framework))

      #client.on("system", (name) -> console.log "update", name )

  class MpdPlayer extends env.devices.Device
    _state: null
    _currentTitle: null
    _currentArtist: null
    _volume: null

    actions: 
      play:
        description: "starts playing"
      pause:
        description: "pauses playing"
      next:
        description: "play next song"
      previous:
        description: "play previous song"
      volume:
        description: "Change volume of player"

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
      volume:
        description: "the volume of the player"
        type: "string"

    template: "musicplayer"

    constructor: (@config) ->
      @name = config.name
      @id = config.id

      @_client = mpd.connect(
        port: @config.port
        host: @config.host      
      )
      
      @_connectionPromise = new Promise( (resolve, reject) =>
        onReady = =>
          @_client.removeListener('error', onError)
          resolve()
        onError = =>
          @_client.removeListener('ready', onReady)
          reject()
        @_client.once("ready", onReady)
        @_client.once("error", onError)
        return
      )

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
    getVolume: ()  -> Promise.resolve(@_volume)
    play: () -> @_sendCommandAction('pause', '0')
    pause: () -> @_sendCommandAction('pause', '1')
    previous: () -> @_sendCommandAction('previous')
    next: () -> @_sendCommandAction('next')
    setVolume: (volume) -> @_sendCommandAction('setvol', volume)

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

    _setVolume: (volume) ->
      if @_volume isnt volume
        @_volume = volume
        @emit 'volume', volume

    _getStatus: () ->
      @_client.sendCommandAsync(mpd.cmd("status", [])).then( (msg) =>
        info = mpd.parseKeyValueMessage(msg)
        @_setState(info.state)
        @_setVolume(info.volume)
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

  # Pause play volume actions
  class mpdPauseActionProvider extends env.actions.ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null

      mpdPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("play") 
      ).value()

      if mpdPlayers.length is 0 then return

      device = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match('pause ')
        .matchDevice(mpdPlayers, onDeviceMatch)
        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new mpdPauseActionHandler(device)
        }
      else
        return null

  class mpdPauseActionHandler extends env.actions.ActionHandler

    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would pause %s", @device.name)
        else
          @device.pause().then( => __("paused %s", @device.name) )
      )

  class mpdPlayActionProvider extends env.actions.ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null

      mpdPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("play") 
      ).value()

      if mpdPlayers.length is 0 then return

      device = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match('play ')
        .matchDevice(mpdPlayers, onDeviceMatch)
        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new mpdPlayActionHandler(device)
        }
      else
        return null
        
  class mpdPlayActionHandler extends env.actions.ActionHandler

    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would play %s", @device.name)
        else
          @device.play().then( => __("paused %s", @device.name) )
      )

  class mpdVolumeActionProvider extends env.actions.ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null
      volume = null

      mpdPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("play") 
      ).value()

      if mpdPlayers.length is 0 then return

      device = null
      valueTokens = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      M(input, context)
        .match('change volume of ')
        .matchDevice(mpdPlayers, (next,d) =>
          next.match(' to ', (next) =>
            next.matchNumericExpression( (next, ts) =>
              m = next.match('%', optional: yes)
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              valueTokens = ts
              match = m.getFullMatch()
            )
          )
        )

        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new mpdVolumeActionHandler(device,valueTokens[0])
        }
      else
        return null
        
  class mpdVolumeActionHandler extends env.actions.ActionHandler

    constructor: (@device, @volume) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would set volume of %s to %s", @device.name, @volume)
        else
          @device.setVolume(@volume).then( => __("set volume of %s to %s", @device.name, @volume) )
      )      
      
  # ###Finally
  # Create a instance of my plugin
  mpdPlugin = new MpdPlugin
  # and return it to the framework.
  return mpdPlugin