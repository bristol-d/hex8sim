# Hex8 instruction set simulator

This is a simulator for the Hex8 instruction set designed by Prof. David May for teaching at the University of Bristol.

For a few years, a physical version existed in Bristol, called the [big hex machine](https://bighexmachine.github.io/).

See the files in modules/ for documentation (or clone/download the repo to use the rendered html versions with syntax highlighting):

  * [Overview](modules/hex8.md)
  * [A sample program](modules/program.md)
  * [Using the stack](modules/stacks.md)

If you want to build the processor yourself,

  * [modulesim](https://github.com/TeachingTechnologistBeth/ModuleSim) simulates the individual components
  * [description of the components](modules/components.md)
  * [building the processor as a sequence of exercises](modules/exercises.md)

The simulator is in [hex.html](hex.html), just download the repository and open the file - all code is client-side js. The source code is in [hex.js](hex.js).

You can paste the compiled binary program from [modules/program.md](modules/program.md) and run it in the simulator, for example.
