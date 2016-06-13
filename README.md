# CaptureTheFlag
an iOS Capture The Flag app written in Swift, using CoreLocation and MapKit.

It’s a live online multiplayer Capture the Flag game, which can be played over any size area. The person to create the game chooses the dimensions and layout of the field, and joiners can hop in. As players join the game, their location is pushed to the database and their displayed to all the other users. 

The player’s location is checked against the boundaries of the map and they are notified if they go out of bounds. Also, proximity-based tagging has been implemented. While a user is in their own territory, they tag any member of the other team who comes too close, and both tagger and tagged are notified via sound effect. Only when in the other team’s territory can users be tagged.

The idea is that once the game begins, a player will be able to see all teammates and also, while in their own region, any players from the other team who have crossed into their region. They will also be able to see the opponent team’s flag but not the exact location of their own, to prevent puppy-guarding of the flag. If a user makes it all the way to the opposing team’s flag without being tagged, they then capture it and have to run it back to their side of the line without being caught in order to win.
