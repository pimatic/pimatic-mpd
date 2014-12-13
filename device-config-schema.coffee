module.exports ={
  title: "pimatic-mpd device config schemas"
  MpdPlayer: {
    title: "MpdPlayer config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      port:
        description: "The port of mpd server"
        type: "number"
      host:
        description: "The address of mpd server"
        type: "string"
  }
}