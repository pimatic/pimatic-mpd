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

###device rules examples:

<b>Play music</b><br>
if smartphone is present then play mpd-player

<b>Pause music</b><br>
if smartphone is absent then pause mpd-player

<b>Stop music</b><br>
if smartphone is absent then stop mpd-player

<b>Change volume</b><br>
if buttonVolumeLow is pressed then change volume of mpd-player to 5

<b>Next song</b><br>
if buttonNext is pressed then play next song Music

<b>Previous song</b><br>
if buttonPrev is pressed then play previous song Music

Currently no predicates for the mpd plugin. If you would like to do something when the state changes u could use the attribute predicate.<br>
if $mpd-player.state equals \"play\" then switch speakers on <br>
if $mpd-player.state equals \"pause\" then switch speakers off <br>
