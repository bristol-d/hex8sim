The Hex8 processor and instruction set
======================================

Registers
---------

A Hex8 processor has four registers, each holding 8 bits.

  - The A register (`areg`).
  - The B register (`breg`).
  - The program counter (`pc`).
  - The offset register (`oreg`).

Execution
---------

Instructions execute as follows.

  1. Load the current instruction from memory - the one that `pc` is pointing at.
  2. Copy the operand (low 4 bits of the instruction byte) into the low 4 bits
     of the offset register.
  3. Increment the program counter.
  4. Execute the instruction.
  5. Unless the instruction was a `PFIX`, set the offset register to 0.

Since the program counter increases _before_ the instruction executes, this
needs to be taken into account if an instruction wishes to modify the program
counter itself.

Instructions
------------

There are 16 Hex8 instructions. In the following, `a <- b` means copy the value
of `b` to `a` (both of these are registers or memory locations) and `mem[x]`
means byte `x` of memory.

Each instruction is one byte long, of which the high 4 bits are the opcode
(given in hex and binary in the table below) and the low 4 bits are the operand
that gets placed in the low 4 bits of `oreg` before the instruction executes.

| hex | binary | opcode | operation | description |
| ---:| ------ | ------ | --------- | ----------- |
| 0 | 0000 | `LDAM` | `areg <- mem[oreg]` | Load A register from memory |
| 1 | 0001 | `LDBM` | `breg <- mem[oreg]` | Load B register from memory |
| 2 | 0010 | `STAM` | `mem[oreg] <- areg` | Store A register to memory  |
| 3 | 0011 | `LDAC` | `areg <- oreg`      | Load a constant into the A register |
| 4 | 0100 | `LDBC` | `breg <- oreg`      | Load a constant into the B register |
| 5 | 0101 | `LDAP` | `areg <- pc + oreg` | Load a pc offset into the A register |
| 6 | 0110 | `LDAI` | `areg <- mem[areg + oreg]` | Indexed load of A register |
| 7 | 0111 | `LDBI` | `breg <- mem[breg + oreg]` | Indexed load of B register |
| 8 | 1000 | `STAI` | `mem[breg + oreg] <- areg` | Indexed store |
| 9 | 1001 | `BR`   | `pc <- pc + oreg`   | relative branch |
| A | 1010 | `BRZ`  | `if areg=0 then pc <- pc + oreg` | conditional branch | 
| B | 1011 | `BRN`  | `if areg<0 then pc <- pc + oreg` | conditional branch | 
| C | 1100 | `BRB`  | `pc <- breg`        | absolute branch using B register |
| D | 1101 | `ADD`  | `areg <- areg + breg` | add, result goes in A register |
| E | 1110 | `SUB`  | `areg <- areg - breg` | subtract, result goes in A register |
| F | 1111 | `PFIX` | `oreg <- oreg << 4` | set high bits of offset register |

Prefixing
---------

Since an instruction only has 4 bits for the operand, the `PFIX` instruction
exists to set the high 4 bits of the offset register. Thus to load the constant
`0xAC` into the A register, the sequence of instructions is `PFIX A, LDAC C` or
`0xFA 4C` in hexadecimal.

After `PFIX A`, the offset register holds the constant `0xA0` (and `PFIX` is the
only instruction that does *not* clear the offset register), then before the
`LDAC` executes the constant `0x0C` is added to the offset making it `0xAC`.

A prefix instruction and its successor can mentally be thought of as a single
instruction with an 8-bit operand, thus `PFIX D, STAM 3` represents "`STAM 0xD3`"
which stores the contents of the A register to memory location `0xD3`.

An important consequence of this choice in creating the instruction set is that
addressing memory at locations `0x00-0x0F` takes one instruction whereas locations
`0x10-0xFF` take two instructions to address directly, thus twice as much space
in the program and twice as much time to execute.

Similarly, relative jumps forward up to 16 bytes are one instruction:
`0x9F = BR F` jumps forwards 16 bytes, 15 (`0x0F`) from the instruction and one
because the program counter has already increased. But backwards jumps, where
the offset is a negative number, take two bytes even if they are only by a
small amount.

Constant instructions
---------------------

`LDAC` and `LDBC` load a 4-bit constant into the A and B registers respectively.
Use a `PFIX` beforehand to load an 8-bit constant.

Arithmetic instructions
-----------------------

`ADD` and `SUB` operate on the A and B registers and place the result in the A
register. They ignore any operands they are given. If an `ADD` overflows, it
just wraps around; `SUB` operates in 2s complement arithmetic e.g. if you
subtract 1 from 0 (`LDAC 0, LDBC 1, SUB`) then you get `0xFF` in the A register
which you can interpret as (-1) in 2s complement or 255 in unsigned arithmetic.

Memory instructions
-------------------

`LDAM` and `LDBM` load the A and B registers respectively from the memory
location indicated by their operand. For access to memory beyond `0x0F`, this
requires a preceding `PFIX` instruction.

`STAM` stores the A register to memory. There is no `STBM` instruction so if you
want to move some data to memory, you should load it into the A not the B
register in the first place. Outputs of `ADD` and `SUB` appear in the A not the
B register for this reason too. If you do need to store the contents of the B
register, the sequence `LDAC 0, ADD` has the effect of copying the B register's
value into the A register from where you can store it; this also erases the old
value of the A register so you need to save that to memory first if you need it.

The instruction `LDAI 0` loads the element from memory at the address which the
A register is currently pointing to, which is why it is called an *indirect load*.
So the sequence of instructions `LDAC 8, LDAI 0` first loads the constant 8 into
the A register, then fetches the element at memory address 8 into the A register.
This sequence is equivalent to `LDAM 8` directly, but you have to do an indirect
load when you need to compute the address you want to fetch from rather than
hard-coding it in your program. `LDBI 0` does the exact same with the B register
for both address and destination.

`LDAI` and `LDBI` with non-zero operands are useful for loading elements from
arrays. If you want to fetch the 5th element of an array of bytes for example,
you first load the address where the array starts into the A register and then
execute `LDAI 4`, since indexing starts at 0. Of course you can use prefixes to
load beyond the 16th element of an array.

`STAI` is an indirect store. To use it, load the value to store into the A
register, the starting address of your data array into the B register and put
the offset into the offset register. For example, if the address of the start of
your data is currently stored at memory address `0x0A` and you want to put a `1`
into the 3rd element, the sequence `LDAC 1, LDBM A, STAI 2` does that for you.
There is no `STBI` instruction.

`LDAP` is used to find the address of a relative jump, useful in constructing
function calls. The point of this instruction is that you can write code which
works wherever in memory you place it. `LDAP 0` gets the address of the *next*
instruction since when the `LDAP` executes, the program counter has already been
incremented.

Branching instructions
----------------------

`BR` is a relative branch. `BR 0 (0x90)` is a no-op since it jumps by 0 after
the program counter has been incremented, thus landing on the next instruction.
The main use of `BR` is jumps within a function or block of code, which being
relative branches means the code does not need to be adjusted if it is moved
somewhere else in memory.

`BRZ` and `BRN` are conditional relative branches. The former branches only if
the A register is exactly zero, the latter if the high bit of the A register is
set (which represents a negative number in 2s complement). These two instructions
can be used to do all the usual conditional tests, for example to branch if
`x > y` you compute `y - x` and branch if the result is negative. To test `x = y`
you compute `y - x` or `x - y` (it doesn't matter which) and then branch if the
result is zero. To test `x >= y` you test for the negation `x < y`.

A combination of `BR`, `BRZ` and `BRN` can implement all the usual control
structures such as IF/ELSE and different forms of LOOP.

`BRB` is an absolute branch where you load the target into the B register first.
It ignores its operand. Its main use is in function calls, where after setting
up parameters and return addresses you load the function's address into the B
register and then call `BRB`. This means that your code will still work if you
move the *calling* code around, though you have to adjust it if you move the
*callee* (i.e. the function you're calling) somewhere else.

Halting the processor
---------------------

The Hex8 processor halts if it encounters a `BR` instruction and the offset
register is set to `0xFE`. The only way to produce this situation is with the
sequence `0xFF 0x9E (PFIX F, BR E)` which would otherwise produce an infinite
loop.

