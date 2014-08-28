module.exports ={
  title: "pimatic-mpd device config schemas"
  MpdPlayer: {
    title: "MpdPlayer config options"
    type: "object"
    properties:
      port:
        description: "The gpio pin"
        type: "number"
      host:
        description: "The host"
        type: "string"
  }
}