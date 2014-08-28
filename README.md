pimatic-mpd
===========

pimatic plugin for controlling the [Music Player Daemon](http://www.musicpd.org/).

###device config example:

```json
{
  "id": "mpd-player",
  "name": "Music",
  "class": "MpdPlayer",
  "host": "192.168.1.2",
  "port": 6600
}
```