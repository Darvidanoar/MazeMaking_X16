# MazeMaking_X16
Maze making using the backtracking algorithm
![MazeMaking_X16](/maze.gif)

## The Algorithm
The algorith uses it's own stack (not the system stack) to keep track of the locations along the path it creates.  This allows it to backtrack when a dead end is reached, by popping the previous location from the stack.  The map is complete when the algorithm has backtracked all the way back to the origin and the stack is empty.  Interestingly, the same algorithm can be used to solve the maze.

The maze is created using the following algorithm:

1. Beginning at the origin, co-ordinates (1,1), choose a random direction.
2. Determine if it is possible to move in that direction.
3. If a move is possible, make the move and push the location co-ordinates onto the program's own stack.
4. Check the new location's neighboring cells to determine whether a move is possible.
5. If a move is possible, goto 1.
6. If a move is not possible, backtrack to the previous location by popping it's co-ordinates off the stack.
7. If the stack is not empty, Goto 1.
8. The maze is complete


## Notes
The Origin of the maze is in the top left of the screen, and the destination is in the bottom right of the screen.  

There are delays in the code to slow the drawing of the map, as I find it interesting to watch.
When the algorithm is in backtracking mode, I have it display a red cell, so we can follow the backtracking process.

On the emulator, CTRL-P will dump a screen capture GIF that can be printed.

At any time, the user can hit the Q key to exit the program.


## Potential Improvements
When the destination cell is reached, the algorith could check the size of the stack.  If the stack size is small, it indicates that the path from Origin to Destination is not very long.  This could cause the program to declare the maze too easy and start again.
