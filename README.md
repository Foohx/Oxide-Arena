# Arena

## Introduction

This plugin, and the minigames that connect to it, will allow you to hold minigames in your custom-built arena. This plugin lets you select custom spawn points, will handle teleporting your players to and from the arena, and easily lets you plug in more Arena minigames.

## Requirements

+ Platform: Linux, Windows or Mac
+ [PlayRust](http://playrust.com/) server in its latest version
+ [Oxide](http://rustoxide.com/) <= 1.17 (and maybe latest)
+ Plugin: [Flags, Spawns](https://github.com/Foohx/Oxide-Arena/tree/master/require)

## Install

Put the plugin arena.lua well as flags.lua plugins and spawns.lua in the plugin folder of your server.
+ arena.lua
+ [require](https://github.com/Foohx/Oxide-Arena/tree/master/require)/flags.lua
+ [require](https://github.com/Foohx/Oxide-Arena/tree/master/require)/spawns.lua

You can also add one or more games, always in the same folder. For this look at the games available in [games/](https://github.com/Foohx/Oxide-Arena/tree/master/games)


## Commands

```
/arena_spawnfile {filename}
```
Tell the Arena system which spawnfile you would like to use for the Arena spawns. For easy directions on how to set up spawns, check the Spawns plugin and watch the video tutorial.
```
/arena_list
```
This lists all the minigames available for play. You can add more minigames by searching the list on the bottom of this page.
```
/arena_game {gameID}
```
Select the next minigame for the Arena. Use "/arena_list" to list all Arena minigames.
```
/arena_open
```
Open the Arena gates. Players may now join using "/arena_join" and may leave using "/arena_leave".
```
/arena_close
```
Close the Arena gates. Players may no longer join, but they are allowed to leave. If you leave the arena gates open while the minigame starts players will be allowed to join in at anytime. The minigame should handle this scenario and everything should be fine.
```
/arena_start
```
Start the Arena minigame.
```
/arena_end
```
Most Arena minigames will end on their own. You may use this command to force an Arena minigame to end early.

