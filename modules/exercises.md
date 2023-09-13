Several bugs have been fixed in this file since the start of term.
This version is from Monday 26 November at 2:30pm.

*Most of these exercises are incremental, that is each exercise asks you to add
something on to the solution of the last one. There are some exceptions that are
indicated as such.*

*You should create a separate modulesim file for each exercise and submit the
files for all exercises to SAFE. In addition, you should submit your table of
instructions that you will create when you come to the control grid part of
these exercises, and any test programs that you have written yourselves.*

*Some exercises have a "checkpoint" at the end. This means that it is worth
showing your design to a TA or staff member at this point, as a mistake here
could lead you down a wrong path for the later exercises.*

Clock circuit
=============

The clock module offers us two phases "a" and "b". However, we need more than
this so we are going to build and 8-phase clock with phases 1a, 1b, 2a, 2b, 3a,
3b, 4a, 4b.

Build a 4-bit counter circuit containing

  * 1 clock
  * 1 AU
  * 1 demultiplexor
  * 2 registers
  * 2 inputs

so that the demultiplexor outputs cycle 1, 2, 3, 4, 1, 2, 3, 4 etc. 
The demultiplexor should step once per full clock cycle on the "a" clock phase.

Further, make sure your demultiplexor does not step immediately after a reset.
In other words, when you press "reset" the demultiplexor should return to output
1 and when you advance the clock to phase "a" then the demultiplexor should
*stay on 1* thoughout this and the following "b" clock phase, and only on the
next "a" clock phase should the demultiplexor advance to output 2.

Note: this is not a complicated task - the demultiplexor simply has to be at the
correct position in the circuit and the "a" and "b" phases need to be in the
right order.

4-bit data path
===============

*This exercise prepares you for the later 8-bit data path that you will use in
your processor. Please use a fresh modulesim file as this exercise does not
contribute to the processor directly.*

A simple data path is simply a loop containing AUs and registers like the counter
circuits you are used to. However, it is configurable in the sense that you can
control which registers are read and written to in each cycle.

Create a 4-bit data path out of the following components:

  * 1 AU
  * 1 clock - set this to *manual*
  * 1 multiplexor
  * 3 registers
  * 2 split/merges
  * 5 inputs
  * 1 fan-out

The AU only needs to support add mode so you can leave its control input empty.
Use one of your registers as a holding register - it should be clocked in phase
"a" and receive values from the AU. We will name the other registers "A" and "B".

  * For one input of the AU, you should be able to choose whether to take a
    value from the "A" register or a switch input.
  * The other AU input can just be connected to the "B" register.
  * One switch input should be on the control input of the AU.
  * The "A" and "B" registers should both clock in the "b" clock phase, however
    you should use a switch and split/merge for each of these two registers so
    that you can choose whether to write to them or not.

When your data path is set up, you should be able to use it for the following
tasks. For each task, the clock should be set to manual so you can alternate
between changing switch inputs and advancing the clock.

  * Load a value into the "A" or "B" register.
  * Copy a value from the "A" to the "B" register or back.
  * Reset a register without using the reset button.
  * Compute 3 + 2 + 2 + 1 and put the result in the "A" register.

You have now built a calculating machine that can execute the following
instructions in any combination and order, though you have to select each one
by hand:

  * `LDAC x` - load value `x` into the "A" register.
  * `LDBC x` - load value `x` into the "B" register.
  * `ADD`   - add the values in the "A" and "B" registers and place the result
    in the "A" register.
  * `CPA` and `CPB` - copy the value from the "A" register to the "B" register
    or vice versa.

The last two are not hex8 instructions, but then a hex8 machine has access to
memory to which it can copy values.

Make a table on paper listing, for each of the four instructions, which inputs
have to be in which positions (i.e. which switches have to be on/off) to get the
data path to execute this instruction. Your table should have one row per
instruction and one column per switch input.

You can start to see how the hex8 computer is going to work. Instead of setting
instructions by hand, the processor will fetch them from memory, decode them and
set the AUs and multiplexors and registers up correctly. The data path is
resposible for actually executing the instructions.

*Checkpoint: show your 4-bit data path and table to a TA or staff member for feedback.*

Data path
=========

*We will now build the real data path - make a copy of your file from the
clock circuit exercise and add to it for this exercise.*

The real data path is 8 bits wide instead of 4, so you need to "double up" the
registers, AUs and multiplexors. Build an 8-bit data path around an AU pair with
the following constraints:

  * Do not connect anything to the clock yet.
  * Use one 8-bit holding register (i.e. a pair of registers linked together)
    like before.
  * Add multiplexors before both AU inputs.
  * Create four 8-bit registers, which we will call "A", "B", "pc" and "O".
      * Do not connect these registers to the AU input multiplexors yet.
      * Fan out the data output from the holding register to the "A", "pc" and
        "B" registers but not the "O" register.

Register File
=============

We need to connect the four working registers up to the AU's input multiplexors.
This exercise is about working out what should be connected to what; the main
effort is theoretical.

Look at the 16 instructions in the [hex 8 notes](hex8.html). Each of these will
use the AU exactly once to do either an addition, or a subtraction, or just pass
a value through unchanged. (Ignore PFIX for now as we'll handle it separately.)

In addition to the instructions, there is another case when we need the AU:
to increment the program counter which we can imagine as `pc <- pc + 1`.

For each of the instructions and for incrementing the program counter, decide
how the AU should be set up by making a table with 3 columns:

  * AU mode (add, subtract, pass through; carry 1 if necessary).
  * AU left input - either a register or a constant, e.g. 0.
  * AU right input - either a register or a constant.

There is one important constraint for this table. The multiplexors on each of
the AU inputs only have 4 possibilities, so the "AU left input" and "AU right
input" columns can only have 4 distinct values each.

Each row of the table should represent one instruction, except that you do not
need a row for the `PFIX` instruction but you should add an extra row for
"increment PC". For example, the cell in the "ADD" row and "AU left input"
column will indicate what the AU left input should be when it is executing an
`ADD` instruction. You can (and later will) add extra columns to this table to
record other information for each instruction.

Once you have created the table, wire up the registers to the multiplexor inputs.
If you have decided that in some row of your table, the left input to the AU
will come from the "A" register then you will need cables from the "A" register
to one input of the multiplexor for the AU left input, for example. If you
decide that a register needs to be connected sometimes to the left input and
sometimes to the right input then put fanouts after the register and connect it
to both multiplexors.

Add the memory
==============

There is nothing interesting in this step but it is separate to make earlier
steps less confusing.

  * Remove the connection going out of the holding register.
  * Add fanouts after the holding register.
  * Add multiplexors after these fanouts. Connect the fanouts to
    the multiplexors on the first port.
  * Connect the multiplexor outputs to the fanouts below the main registers
    such that if the multiplexors have control input `0000`, the data path works
    like it did before.
  * Now connect the fanouts to the "A" and "B" address ports of the memory
    and the data out ports of the memory to the second input of the multiplexors.

We have now created a system in which we can switch the multiplexors to read
from memory instead of from the AU. This way, with a
simple switch, we can modify the `areg <- oreg` instruction (copy the "O"
register to the "A" register) to perform `areg <- mem[oreg]` instead, that is
read the value at the memory location pointed to by the "O" register into the
"A" register.

  * Next, place fanouts after the "A" register if you have not done so already
    and connect one of their outputs to the data inputs of the memory. This
    means that the only way we can get data into memory is through the "A"
    register but this is fine as both instructions that store values, `STAM` and
    `STAI`, both use the "A" register as the source of data.
  * Make sure the write-enable switch on the memory is *OFF* for now.

Opcodes and clocks
==================

The eight clock phases 1a - 4b will be used as follows.

  * 1: fetch the next instruction
  * 2: increment the program counter
  * 3: execute the instruction
  * 4: unused

In more detail, The "a" phases all clock the holding register and the "b" phases
copy it to where its value should go. So the clock phases are:

  * 1a: copy pc to holding register, to fetch the next instruction from memory.
  * 1b: save opcode and operand into registers.
  * 2a: increment pc and put result into holding register.
  * 2b: copy result from holding register back into pc.
  * 3a: execute operation and put result into holding register.
  * 3b: copy the result to wherever it belongs (register or memory).

To implement this, create a 4-bit opcode register and set it to clock in phase
1b. This means to place a split/merge before its control input and connect the
clock phase "b" and demultiplexor "1" signals to it correctly.

Next, create a connection from the fanout from the high 4 bits coming out of the
holding register into the opcode register.

The beginning of the control grid
=================================

The data path has a number of components that have different configurations,
for example:

  * The AU can be in add or subtract mode and the carry in can be on or off.
  * The MUXes before the left and right inputs to the AU can be in one of four
    input configurations each.
  * The MUXes after the holding register can be in "read from holding register"
    or "read from memory" configurations.

The control grid will contain a number of chained ORs that control what the data
path does at any particular moment. 
    
Suppose that we want the holding register MUXes to be in "read from memory" mode
whenever we're in clock phase 1 (to load a new instruction) or we're executing
a `LDAM` instruction (we'll come to that later on). In this case we could place
a chained OR in the control grid, label it something useful like "mem read" and
connect the output of this chained OR to the control signal of the holding
register MUXes. Then we create a wire that's on whenever we're in clock phase 1
and connect it to one input of the chained OR, and we create another wire that's
on whenever we're executing `LDAM` and connect that to another input of the
chained OR.

If we wanted to have a component in the data path do something whenever e.g. the
clock phase is 3 AND the instruction is `PFIX`, we can use another MUX to achive
this: we could connect the "clock phase 3" signal to the control input of the
MUX and the `PFIX` signal to the *second* data input of the MUX. This way, the
output of the MUX will be on whenever both conditions are true (this assumes
that both input signals are `0001` for on and `0000` for off, which is generally
the case).

Your first task for this exercise is to come up with a short name for every
control input to the data path and add these names as columns to your table that
you created earlier for the "register file" exercise. Then place a chained OR
for each control input you have identified and connect its output to the control
signal in question. As you implement more instructions, keep track in the table
of which instructions and/or clock phases need which control signals on the data
path to be active.

For each register you will need a separate "enable" control input. For example,
in the `LDAC` instruction you want to write to the "A" register but not the "B"
register. So in the table row for the `LDAC` instruction you want a 1 in the
"write A register" column and on your control grid, the `LDAC` wire from the
decoder needs to connect (among other things) to the chained OR for the "write
A register" signal.

Implementing a new instruction always means the following steps:

  * Decide how the data path needs to be set up for this instruction and record
    this information in the table.
  * Connect the necessary wires in the control grid, as indicated in the table.
  * Test that it works.

Your second task is to deal with the problem that the inputs to the MUXes for
the left and right inputs to the AU are two-bit signals, as there are four
inputs to each MUX. You might not need all four inputs but you'll need more than
two.

A two-bit signal is a combination of two one-bit signals. To complete the second
task, use split-merges to combine the signals. For the left and right MUXes before
the AU, you will need at least two chained ORs and one split-merge to select the
correct input. The idea is that one chained OR controls the low-order bit and the
other chained OR controls the second-lowest bit of the MUX control input. If in a
particular instruction you want both bits on the MUX control input to be on, you
pass the relevant wire through both the chained ORs for this MUX.

Note: suppose that when clock phase 2 is active, you want several things to
happen on the data path. The wrong way to achieve this is to place a fan-out on
the "phase 2" signal and wire it up to all chained ORs that you want it to
activate. The correct way is to connect the "2" signal to the input of the first
chained OR and then connect the matching output of the chained OR to an input of
the next one, and so on.

*Checkpoint: show your table and your processor to a TA or member of staff.*

The program counter
===================

The aim of this exercise is to get the PC to increment in clock phase two.

  * In clock phase 2a, the AU should take the PC as input and add one, sending
    the result to the holding register (which clocks in every "a" clock phase).
  * In clock phase 2b, the PC should write. (You have hopfully already set up
    you data path such that the input to the PC comes from the holding register.

To get clock phase 2a to work correctly, think about which control signals you
need to be active. You can use the "2" signal as input to the chained ORs as it
doesn't do any harm to keep the data path in the same configuration for phases
2a and 2b - the holding register doesn't do anything in the "b" phases after all.

To get the PC to write in clock phase 2b, you don't need any chained ORs yet -
just use a split-merge to combine the "2" and "b" signals correctly, such that
if you press the reset on the clock then this signal gets through whatever the
clock phase is.

The decoder
===========

This exercise is to fetch and decode instructions in clock phase 1.

In clock phase 1a, we want to read the current instruction from memory. This
means that the data path should copy the PC to the holding register, which in
turn drives the memory address input.

Implement this by adding any components and wires necessary to the control grid.
As in the last exercise, you can simply use the "1" clock signal: it doesn't
matter what the AUs are doing in phase "b".

In clock phase 1b, we want to store the opcode (the high four bits that we just
fetched from memory into the holding register) into a separate register.

  * Add a new 4-bit register, which we will call the opcode register.
  * Set it to clock in phase 1b only (use a split-merge).
  * Label it "opcode" (Control+L in the simulator sets a label).
  * The memory data goes through the MUXes after the holding register and from
    there to a fanout. Connect the upper 4 bits from this fanout to the input of
    the opcode register.
  * Connect the low 4 bits from this fanout to the lower half of the "O" register.

You can now do your first test of the processor. Create a file with the following
contents in a text editor and save it as `test.hex`.

    11 22 33 44 55 FF

  * In the simulator, right-click the memory and choose "View/edit NRAM data".
  * In the window that opens, choose "File/Load Data" and select the file that
    you just created.
  * Lower the speed of your simulation and reset the clock.

If you have wired up everything correctly, the PC should increment by one on
each complete clock cycle and the operand register should cycle through the
values `0001`, `0010`, `0011`, `0100`, `0101`, `1111` and then reset to `0000`,
stepping in clock phase 1b each time (the PC steps in 2b).

Decoding
========

Now that we have saved the opcode in a register, we want to decode it. Decoding
means taking the opcode, which is one 4-bit signal, and using it to activate one
of `2^4 = 16` one-bit signals, one for each instruction. This way, whenever say
an `ADD` instruction is being executed only the `ADD` signal is on and we can
use it to set up the data path appropriately.

Your task is to use demultiplexors to decode the signal from the opcode register
into one of 16 1-bit signals.

  * The signal from the opcode register should connect to the control inputs of
    the demultiplexors.
  * A single demultiplexor takes a 2-bit control signal. Use a split-merge in
    "split" arrangement to split the 4-bit signal from the opcode register into
    two 2-bit signals.
  * For the data input of the demultiplexors, use the phase "3" (execute) clock
    signal. This has the effect that in clock phase 3, exactly one of the 16
    signals is `0001` whereas in the other clock phases, all 16 signals are off.
    After all, we only want the data path to execute the instruction in phase 3,
    in phases 1 and 2 it's already in use for fetching the instruction and
    incrementing the PC.

*Checkpoint: show your processor design to a TA or staff member for feedback.*

The "O" register
================

The "O" register is special in that the high and low halves operate differently.

  * For any instruction except `PFIX`, the low 4 bits representing the operand
    need to be copied into the "O" register *before* the instruction executes.
  * A `PFIX z` instruction results in the 4-bit value `z` being placed in the
    high 4 bits of the "O" register for the *next* instruction.
  * For any instruction except `PFIX`, the high 4 bits of the "O" register must
    be set to zero *after* the instruction has executed.

For this to work correctly, set the low 4-bit part of the "O" register to clock
in phase 1b and feed the low 4 bits of the holding register into it (this happens
at the same time as the high 4 bits get sent to the opcode register).

Set the high 4 bits of the "O" register to clock in phase 3b. 

Use a new MUX to control the data input to the high bits of the "O" register:

  * If the instruction is `PFIX`, the MUX should feed the low "O" register bits
    through to the high ones (the MUX can be on throughout multiple phases, all
    that matters is that it is on in phase 3b when the high "O" register clocks).
  * If the instruction is not `PFIX`, the MUX should feed `0000` to the high "O"
    register. You don't need an input component - just leave the MUX input empty
    for this.
  * The control input of this MUX should therefore be the `PFIX` signal from the
    decoder that you built in the last exercise. This will only ever be on in
    phase 3 so you don't need an extra MUX to deal with clock phases.

Create a text file called `pfix.hex` with the following contents and load it as
described in the decoder exercise:

    00 01 0f f1 02 ff 03 fe fd 01

The "O" register should cycle through the following values when you reset and
run your processor. You probably want to step through the instructions manually
(SPACE pauses the processor; reset it then the DOT (.) key advances one step).
Note that the low 4 bits change on 1b and the high ones on phase 3b.

    Hex  Bin        Instruction  Phase
    ---  ---------  -----------  -----
    00   0000 0000  0            all
    01   0000 0001  1            1b
    0f   0000 1111  2            1b
    01   0000 0001  3            1b
    11   0001 0001  3            3b
    12   0001 0010  4            1b
    02   0000 0010  4            3b
    0f   0000 1111  5            1b
    ff   1111 1111  5            3b
    f3   1111 0011  6            1b
    03   0000 0011  6            3b
    0e   0000 1110  7            1b
    ee   1110 1110  7            3b
    ed   1110 1101  8            1b
    dd   1101 1101  8            3b
    d1   1101 0001  9            1b
    01   0000 0001  9            3b
    00   0000 0000 10            1b

Congratulations, you have implemented your first processor instruction!

Constant loads : LDAC and LDBC
==============================

Your next instructions to implement are `LDAC` and `LDBC`. Looking at the
[instruction table](hex8.html), all these instructions do is copy the "O"
register into the "A" resp. "B" register. Since the instruction executes in
clock phase 3 and the current operand is already stored in the "O" register
in phase 1b, this has the effect of copying the current operand (plus any prefix
from the last instruction) into the "A" resp. "B" registers.

Task: implement `LDAC` and `LDBC` by creating the appropriate connections in the
control grid. Specifically,

  * If the instruction is `LDAC` or `LDBC` then the data path should pass the
    contents of the "O" register through the AU during phase 3, with the result
    that this value gets copied to the holding register in phase 3a.
  * In phase 3b, you want to clock the "A" register if it's a `LDAC` and the "B"
    register if it's a `LDBC`.

Remember that each register has a split/merge before its control input that
combines a clock and an enable signal. The clock signal for the "A" and "B"
registers' split-merge inputs should be just the "b" clock signal (this lets
resets through as well); the enable part should only be active when you really
want to write. At the moment, the enable signal for the "A" register should be
on exactly when the clock is in phase 3 AND the current instruction is `LDAC`.

Hint: you don't need to do anything complicated to get the "AND" in the last
sentence right. The `LDAC` signal from the decoder is alredy such that it's only
on when the phase is 3 and the instruction is `LDAC`. So at the moment you can
just connect the `LDAC` signal from the decoder to the enable input of the "A"
register split/merge. Later when you have several instructions that write to the
"A" register, the enable signal will come from a new chained OR that combines
the signals for all these instructions.

*Remember to update your table of control grid settings too (from an earlier
exercise) whenever you change the control grid. It will come in useful as your
grid becomes more complex.*

To test your processor, create a file `ldac.hex` with the following contents and
run it:

    31 32 f3 34 41 42 f3 44

This disassembles to the following instructions:

    31  LDAC 1
    32  LDAC 2
    F3  PFIX 3
    34  LDAC 4
    41  LDBC 1
    42  LDBC 2
    F3  PFIX 3
    44  LDBC 4

So when you run the file, you should see first the "A" then the "B" register
step `0000 0000`, `0000 0001`, `0000 0010` and `0011 0100`.

*Checkpoint: show your processor design to a TA or staff member for feedback.*

Arithmetic : ADD, SUB, LDAP
===========================

Implement the following instructions by adding to the control grid:

    opcode  mnemonic  semantics
    ------  --------  ---------
    0101    LDAP      areg <- pc   + oreg
    1101    ADD       areg <- areg + breg
    1110    SUB       areg <- areg - breg

Although `LDAP` has a different use in programs, in the processor it is very
similar to `ADD` - just the input MUXes to the AU are set differently. `SUB`
needs the AU to be in subtract mode; be careful about how you have to set the
carry in. The AU takes a three-bit control signal (the high bit is unused, see
the [component description](components.html)).

Since all these instructions, as well as `LDAC` previously, write to the "A"
register you will need a chained OR for the "A" register enable signal.

You should come up with your own test program to test that these three
instructions are working correctly. This involves both writing a test program
and documenting what effects you expect to see when that will tell you whether
your processor is working correctly.

Memory reads
============

You have already implemented `LDAC: areg <- oreg` by setting up the data path so
that in phase 3a, the "O" register contents go through the AU into the holding
register; in phase 3b you copy the holding register to the "A" register.

`LDAM: areg <- mem[oreg]` is almost identical to `LDAC`, there is only one
component on the data path that you have to set differently. Can you see it?
`mem[oreg]` means the value in the memory at address `oreg`, which you get by
feeding the "O" register into the memory's address input and reading the result
off the memory's data output.

Once you know what to do, implement the following instructions.

    opcode  mnemonic  semantics
    ------  --------  ---------
    0000    LDAM      areg <- mem[oreg]
    0001    LDBM      breg <- mem[oreg]
    0110    LDAI      areg <- mem[areg + oreg]
    0110    LDBI      breg <- mem[breg + oreg]

Then, write your own test program(s) and document what you are expecting to see
when you run these programs to tell you that your processor is working correctly.

Storing to memory
=================

This task is to implement the following two instructions, which as usual means
adding things to the control grid to set the data path correctly in phase 3.

    opcode  mnemonic  semantics
    ------  --------  ---------
    0010    STAM      mem[oreg] <- areg
    1000    STAI      mem[breg + oreg] <- areg

`STAM` means take the value in the "A" register and store it in memory at the
location pointed to by the "O" register. To do this, in phase 3a we want to copy
the "O" register to the holding register, which feeds the memory's address input.
The memory's data input (which we haven't used yet) needs to come from the "A"
register and the memory's control input needs to be at `0101` (just like a
register) in phase 3b.

Hint: before you build in complicated switching logic, note that these are the
only operations that write to memory and both take their data input from the "A"
register.

*You also need to turn the memory's write enable switch on. In the simulator,
click it and it should turn blue. When the memory is writing data, the write
LED comes on.*

As before, you should write and document your own test program(s). This also
applies to the following exercises, where it will no longer be mentioned.

Unconditional branching
=======================

There is nothing new about the following branching instructions. They just load,
compute and store data in a register, except now they store to PC instead of the
"A" register.

    opcode  mnemonic  semantics
    ------  --------  ---------
    1001    BR        pc <- pc + oreg
    1100    BRB       pc <- breg

There is however something new about when you enable the PC. It should write:

  * Always, in phase 2b (for increment).
  * Again in phase 3b, but only if the instruction is a branch.

That is the real task of this exercise. Hint: write out the enable condition for
the PC as a formula with AND and OR connectives. Then build a circuit for the
formula, using a chained OR for an OR and a MUX for an AND. (One could use LUs
too with a fixed control signal, if one really wanted to.)

Note: if instruction 4 is `BR 2` then the PC ends up at `7 = 4 + 2 + 1`, not 6.
This is the correct behaviour! The reason is that in phase 2 of instruction 4
you already incremented the PC to 5; in phase 3 you add the 2 from the operand
to it again to get 7. It is the hex8 programmer's job to take this into account.

Conditional branching
=====================

Our final instructions are the following:

    opcode  mnemonic  semantics
    ------  --------  ---------
    1010    BRZ       if areg = 0 then pc <- pc + oreg
    1011    BRN       if areg < 0 then pc <- pc + oreg

There are two parts to implementing them.

First, place a new 8-bit AU pair in your design; you'll use it for the "if"
tests. The only thing we want to test is the "A" register value, so connect the
"A" register to the new AU left inputs.

Secondly, set up the control grid. You now have a new control signal to select
if the comparison AUs should test for 0 or negative and the PC enable condition
is now:

  * Always, in phase 2b (for increment).
  * Again in phase 3b, if the instruction is `BR` or `BRB`.
  * Again in phase 3b if the instruction is `BRZ` or `BRN` and the comparison
    signal (the comparison output of the new AUs) is on.

Congratulations - you have built a complete processor!
