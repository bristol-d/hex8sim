Programming Hex8 in machine code
================================

We want to write a program that takes five numbers and computes their average.
We will assume for now that the sum of the five numbers does not exceed 255 or
we would have to deal with overflows (or use a 16-bit processor) and we will
round up the average to the nearest whole number (so the average of 1,1,2 is 2
which is 1.33... rounded up).

Memory layout
-------------

Our memory is a block of 256 bytes and we are free to choose where to place the
inputs, temporary variables, main code, functions etc. subject to only two
considerations. We will give all addresses in hexadecimal notation so they are
exactly two characters long.

  * Program execution begins at the first address 0x00.
  * To load/store to an address in memory from 0x10-0xFF requires two
    instructions and thus two processor cycles, i.e. storing the A register to
    0x12 is PFIX 1, STAM 2 whereas the adresses 0x00-0x0F need only one cycle to
    access (this is a consequence of our instruction set, not our memory type).
    By using these low addresses as temporary storage, we can make a program up
    to twice as fast.
    
We will arbitrarily make the following choices. This is called dividing memory
into *sections* (sometimes also called *segments*).

  * Temporary storage in addresses 0x00-0x0F.
  * Our inputs will be in 0x10-0x14.
  * The main program code will start at 0x20. Functions that we need will live
    higher up in memory.

Wait ... doesn't a program have to start at 0x00? It does, but we can begin with
instructions to jump to our real start point at 0x20. Once we've done this, we
can overwrite 0x00 with data if we want, as execution is never going to return
there. To jump to 0x20 the instructions are `PFIX 2, LDBC 0, BRB` which puts the
address 0x20 in the B register and then jumps to it. Our program will then
start like this the format is `address: instruction  meaning`.

    0x00: F2  PFIX 2
    0x01: 40  LDBC 0
    0x02: C0  BRB

(There is another way to do this that takes only two instructions, we'll come to
that in a moment.)

So here's how our program will look like. The values before the colon (:) are
addresses and not part of the program itself.

    0x00: F2 40 C0 00 00 00 00 00 00 00 00 00 00 00 00 00
    0x10: (data will go here)
    0x20: (actual program starts here)

The start of our program
------------------------

In our actual program, the first thing we want to do is add the five numbers
stored at 0x10-0x14. In a higher-level language, we could think of them as an
array `a` and we would write code like `s = a[0] + a[1] + a[2] + a[3] + a[4];`.
In assembly we not only need to do things one step at a time, we also need to
think about where our values are stored - variables like `a` or `s` are only
names for memory addresses, which our compiler translates into the real memory
addresses for us. In our case `a` is at 0x10 and let's say we want the result
`s` in 0x01. The procedure is:

  * fetch the value at 0x10 into the A register
  * fetch the value at 0x11 into the B register
  * add the A and B registers, the result will end up in the A register
  * fetch the value at 0x12 into the B register
  * add the A and B registers, the result will end up in the A register
  * fetch the value at 0x13 into the B register
  * add the A and B registers, the result will end up in the A register
  * fetch the value at 0x14 into the B register
  * add the A and B registers, the result will end up in the A register
  * store the A register's value to the address 0x01

Which immediately gives us the following code (anything after `--` is a comment)

    -- load from 0x10 into A
    -- since we need to set the high bits, we need a prefix instruction:
    -- these two instructions are the equivalent of a hypothetical "LDAM 0x10"
    F1  PFIX 1
    00  LDAM 0
    -- load from 0x11 into B, "LDBM 0x11"
    F1  PFIX 1
    11  LDBM 1
    -- add, result lands in A
    D0  ADD
    -- load from 0x12 into B, "LDBM 0x12"
    F1  PFIX 1
    12  LDBM 2
    -- add
    D0  ADD
    -- load from 0x13 into B, "LDBM 0x13"
    F1  PFIX 1
    13  LDBM 3
    -- add
    D0  ADD
    -- load from 0x14 into B, "LDBM 0x14"
    F1  PFIX 1
    14  LDBM 4
    -- add
    D0  ADD
    -- store into 0x01.
    -- since the high 4 bits are all 0, we don't need a PFIX.
    20  STAM 1

This gives us the following program fragment:

    F1 00 F1 11 D0 F1 12 D0 F1 13 D0 F1 14 D0 21

Since the fragment does not reference any code addresses (e.g. for jumps) we
could put it *anywhere* in memory and as long as we got there, it would work.

To try this out, let's pick the numbers 5, 6, 5, 6, 8 as our data to get the
following program:

    0x00: F2 40 C0 00 00 00 00 00 00 00 00 00 00 00 00 00
    0x10: 05 06 05 06 08 00 00 00 00 00 00 00 00 00 00 00
    0x20: F1 00 F1 11 D0 F1 12 D0 F1 13 D0 F1 14 D0 21

We also need a way to tell the program to stop at the end and the sequence
`FF 9E` does this for us. We'll see why this sequence was chosen later on.
The following bytes (minus addresses) can be pasted directly into a simulator:

    F2 40 C0 00 00 00 00 00 00 00 00 00 00 00 00 00
    05 06 05 06 08 00 00 00 00 00 00 00 00 00 00 00
    F1 00 F1 11 D0 F1 12 D0 F1 13 D0 F1 14 D0 21 FF
    9E

The result should be that the A register contains 0x1E (=decimal 30), the sum of
our five numbers. You can also try the program out for different numbers, of 
course.

A function for division
-----------------------

Now that we've added the numbers, we want to divide the result by 5 and round
up. But our processor doesn't have a `DIV` instruction, so we'll have to code it
ourselves. We'll use repeated subtraction which is not an efficient way to do
division for large numbers, but our numbers will only ever grow as far as 255
and it makes the idea easier to illustrate.

Instead of just coding this specific division, we'll write a general-purpose
division with remainder function.
For this we need to define a *calling convention*, saying how the function gets
its inputs, what memory it can use for temporary variables and where it should
put its return value. Here's one option (which we won't end up using):

  * the function expects the dividend in the A register and the divisor in the
    B register
  * the function will return the rounded **down** result in the A register and
    the remainder in the B register
  * the function may use the memory at 0x00-0x0F for temporary variables

So if A = 0x20 (decimal 32) and B = 0x05 when we call the function then we want
A = 0x06 and B = 0x02 when it returns as 32/5 = 6 remainder 2. (We'll round up
the average that we want afterwards.) Except that this convention won't work.

To call our function, we just need to load the A and B registers with the
correct inputs and then jump to the start of the function. But when the function
finishes, we need to jump back to "the place where we came from" since we might
have a larger program that calls the function from several different places. So
our function needs an extra input, the *return address* which the caller is
responsible for setting. (Most processors have special instructions for this,
for example the x86 family has a `CALL (address)` instruction that does all the
work necessary to call a function and `RET` that returns cleanly at the end.)

Since we only have two registers but three inputs, some of them will have to go 
into memory locations. (If you already know what a *stack* is, we're deliberately
**not** using one here.) In fact I'd prefer them all in memory locations, since
the function will need the registers to do its work so if the inputs were in
registers, the first thing the function would have to do is save them to memory
anyway. (This is much less of a problem on a machine with more registers -
nowadays both x64 and RISC tend to have at least 16 registers readily available.
And registers are much faster to access than memory so keeping everything there
saves execution time.)

Here's the calling convention we'll be using for the division function:

  * the function expects the return address in memory location 0x00, the
    dividend in memory address 0x01 and the divisor in 0x02.
  * the function returns the quotient in memory location 0x03 and the remainder
    in 0x03.
  * the function may use 0x00-0x0F for temporary variables

Performing division with remainder
----------------------------------

Let's think how we would divide with remainder through repeated subtraction in a higher language. The idea is to repeatedly subtract the divisor from the
dividend and add one to the quotient each time we do this; stop when the
dividend is smaller than the divisor (at which point what's left in the dividend
is the remainder). Something like this:

    function div_rem(dividend, divisor)
        quotient := 0
        while (dividend - divisor >= 0)
            dividend := dividend - divisor
            quotient := quotient + 1
        end
        remainder := dividend
        return quotient, remainder
    end

Let's allocate variables as follows.

    0x00 = return_address
    0x01 = dividend
    0x02 = divisor
    0x03 = quotient
    0x04 = remainder

Assembly doesn't have blocks and if/for/while constructs, so we have to use
branching instructions (otherwise known as GOTOs). Specifically we can do three
kinds of branches:

  * *absolute branch*, load an address into theB register and go to it with BRB
  * *relative branch*, jump forwards/backwards from the current position with BR
  * *conditional branch*, do a relative branch if A is 0/negative (BRZ/BRN)

Before we start working out branches, let's write one more version of our
function with *labels*, placeholders for memory addresses that we'll fill in
later. We'll use `GOTO label` and `GOTO label IF v=0` and `GOTO label IF v < 0`
to denote non-conditional and conditional branches.

    function div_rem(dividend, divisor)
        quotient := 0
        LOOP:
        GOTO END_LOOP IF (dividend - divisor) < 0
        dividend := dividend - divisor
        quotient := quotient + 1
        GOTO LOOP
        END_LOOP:
        remainder := dividend
        return quotient, remainder
    end

This is a simple expansion of a while loop: at the start of each pass through
the loop we check if the condition is true and exit if it's not; then we go
through the loop and return to the start. We can start converting this to
assembly, leaving in variable names and labels for now.

    -- set quotient to 0
    LDAC 0
    STAM quotient
    LOOP:          -- this is not an assembly instruction!
    -- compute (dividend - divisor) and jump to end of loop if it's negative
    LDAM dividend
    LDBM divisor
    SUB            -- A register now holds difference
    BRN END_LOOP
    -- next up is "dividend := dividend - divisor" but
    -- if we're here then the difference we want is already in the A register
    -- so we can just store it into the dividend
    STAM dividend
    -- increase quotient by 1
    LDAM quotient
    LDBC 1
    ADD
    STAM quotient
    -- and back to the loop start
    BR LOOP
    END_LOOP:      again a label not an instruction
    -- remainder := dividend (yes we could optimise this a bit)
    LDAM dividend
    STAM remainder
    -- to return, we want to load the return address in the B register and BRB
    LDBM return_address
    BRB            -- Be Right Back :)

The nice thing about this code is that it references no memory addresses
directly so we can put it, and its variables, anywhere in memory. But we can't
execute it yet like this. Let's first substitute in the variable addresses.
Since they're all of the form 0x0* we don't have to use any prefixing.

              LDAC 0
              STAM 3
    LOOP:     LDAM 1
              LDBM 2
              SUB
              BRN  END_LOOP
              STAM 1
              LDAM 3
              LDBC 1
              ADD
              STAM 3
              BR   LOOP
    END_LOOP: LDAM 1
              STAM 4
              LDBM 0
              BRB

Since we're using relative branches (one absolute, one conditional) we can
compute the branch *offsets* before we've decided where in memory to stick this
code. Code that does not have absolute jumps is called *position-independent*
and generally nicer to work with.

The instruction `BRN END_LOOP` needs to jump forward 7 instructions. But, when
our instruction executes the processor has already increased the program counter
to the next instruction so we'd only have to jump forwards 6 more.
The `BR LOOP` has to jump backwards 9 isntructions, 10 to compensate for the
already increased PC. How do we jump backwards? 256 - 10 = 246 which is
hexadecimal 0xF6, so we just need to "BR 0xF6" ... which takes two bytes,
`PFIX F, BR 6`. At which point our branch instruction has moved one position
further in our code, so we need to adjust again.

If we don't care about maximum efficiency and don't want to spend ages adjusting
and re-adjusting, we can cheat a bit and represent all jumps as 2 bytes, since
we're allowed to do a `PFIX 0` if we want to (this is also called a *no-op* as
it doesn't do anything except use up space). So let's rewrite one last time,
putting a `PFIX` before each relative branch:

     0           LDAC 0
     1           STAM 3
     2 LOOP:     LDAM 1
     3           LDBM 2
     4           SUB
     5           PFIX ?
     6           BRN  END_LOOP
     7           STAM 1
     8           LDAM 3
     9           LDBC 1
    10           ADD
    11           STAM 3
    12           PFIX ?
    13           BR   LOOP
    14 END_LOOP: LDAM 1
    15           STAM 4
    16           LDBM 0
    17           BRB

And now we can really just read off the offsets. The BRN in line (byte) 6 jumps
to line 14, a difference of 8 - but since the program counter has already
increased we only need to add 7. The formula is, if we want to jump from line
`x` to line `y` we need to set the offset to `y-x-1`, adding 256 if this becomes
negative. In line 13 we want to jump to 2, `2-13-1 = (-12)` so we add 256 to get
244 (0xF4). Which finally gives us the following code, with the assembled byte
before the instruction name:

     0           30  LDAC 0  
     1           23  STAM 3
     2 LOOP:     01  LDAM 1
     3           12  LDBM 2
     4           E0  SUB
     5           F0  PFIX 0
     6           B7  BRN  7
     7           21  STAM 1
     8           03  LDAM 3
     9           41  LDBC 1
    10           D0  ADD
    11           23  STAM 3
    12           FF  PFIX F
    13           94  BR   4
    14 END_LOOP: 01  LDAM 1
    15           24  STAM 4
    16           10  LDBM 0
    17           C0  BRB

Let's put this function at memory address 0x40, so our program looks like this.

    0x00: F2 40 C0 00 00 00 00 00 00 00 00 00 00 00 00 00
    0x10: 05 06 05 06 08 00 00 00 00 00 00 00 00 00 00 00
    0x20: F1 00 F1 11 D0 F1 12 D0 F1 13 D0 F1 14 D0 21
    0x30: (to do)
    0x40: 30 23 01 12 E0 F0 B7 21 03 41 D0 23 FF 94 01 24
    0x50: 10 C0

By the way, I mentioned there was another way we could jump to 0x20 from the
very beginning. This is of course a relative branch: since we need to jump more 
than 0x0F bytes forward we need a PFIX so the alternative start `0x00: F1 9D`
(`PFIX F, BR D`) gets us there in 2 bytes. Bear in mind that the `BR` is byte 2
by which time the program counter is already at 0x03, and 0x03 + 0x1D = 0x20.

Finishing the program
---------------------

We still have three points open:

  * We need to call the division function, for which we need the parameters and
    return address set up.
  * When it returns, we need to round up if the remainder is not 0.
  * Then we need to halt the program, preferably with our result somewhere
    useful (let's use the A register).

Our main program currently stops at 0x2E at which point we've just put the sum
of our five numbers in memory at 0x01, which is where we want it. We can load
the constant 5 into 0x02 with `LDAC 5, STAM 2 (0x35, 0x22)`. Next up we want
to put the return address into memory at 0x00. What is the return address? If I
tell you that our function call will take 5 bytes including prefix and that
we're currently up to byte 0x30, then we can use bytes 0x31-0x35 for the call
and so we'll want to return to 0x36.

We could hard-code the return address, but it's much better to compute it so
we don't have to redo everything if we move the main code around. This is what
the `LDAP` instruction does, it fetches the current program counter into the A
register from where we can store it. Consider the following code:

    0x31: 54  LDAP 4
    0x32: 20  STAM 0
    0x33: F4  PFIX 4
    0x34: 40  LDBC 0
    0x35: C0  BRB

The `PFIX 4, LDBC 0` puts the address 0x40 of the function we're about to call
in the B register, `BRB` then calls it. We're hard-coding the function address
but this is unavoidable: if we move the division function around then we will
need to change the address here. But if we move the main function (the bit of
code we're currently working on) around, we won't need to change anything.

`LDAP 4` fetches the current program counter plus 4 into the A register
(since we know our jump code is 5 bytes, minus one because the counter has
already advanced to 0x33 when we're executing instruction 0x32).
`STAM 0` then saves it into 0x00 where the function expects it.

When we return to 0x37, we know the quotient will be in 0x03 and the remainder
in 0x04. We need to check if the remainder is 0 and add one to the quotient to
round up in this case. The only place we can check if something is 0 is in the
A register; if so then we want to add 1 to the quotient, if not we simply skip
the adding-1 part.

    0x36:      LDAM 4   -- the remainder
               BRZ  IS0 -- IS0 is a label
    -- if we're here, we didn't branch so the remainder is not zero
    -- so we add one to the quotient
               LDAM 3   -- the quotient
               LDBC 1
               ADD
               STAM 3
          IS0: LDAM 3   -- put the result in A register
    -- now we want to halt the program

The offset here is 4 bytes (5 instructions minus 1 for the advanced program
counter) so this assembles to `0x04 A4 03 41 D0 23 03`.

Halting the program
-------------------

The "magic" instruction to halt a program is `0xFF 9E`. This disassembles to
`PFIX F, BR E` which would be a relative branch of `0xFE`, i.e. two bytes
backwards. But since this sequence is exactly two bytes long, this would cause
an infinite loop. So this instruction sequence is useless in a program and was
chosen as the halt instruction. Specifically, the processor halts if it gets a
`BR` instruction and the offset register has the value `0xFE`, which only this
sequence can produce. If you really want an infinite loop you can use the three-
byte `0xF0 FF 9D` instead.

The final program
-----------------

Putting it all together we get this program. (We've set 0x3F to 0x00 which
doesn't matter since we'll stop before we ever get there.)

    F2 40 C0 00 00 00 00 00 00 00 00 00 00 00 00 00
    05 06 05 06 08 00 00 00 00 00 00 00 00 00 00 00
    F1 00 F1 11 D0 F1 12 D0 F1 13 D0 F1 14 D0 21 35
    22 54 20 F4 40 C0 04 A4 03 41 D0 23 03 FF 9E 00
    30 23 01 12 E0 F0 B7 21 03 41 D0 23 FF 94 01 24
    10 C0

And here it is disassembled, with annotations.

    -- SECTION: local variables (and the loader)
    -- initial loader, jump to _start
    0x00:          F2  PFIX  2  -- these 3 are "GOTO _start"
    0x01:          40  LDBC  0  
    0x02:          C0  BRB   0

    -- empty space
    0x03:          00  
    0x04:          00  
    0x05:          00  
    0x06:          00  
    0x07:          00  
    0x08:          00  
    0x09:          00  
    0x0A:          00  
    0x0B:          00  
    0x0C:          00  
    0x0D:          00  
    0x0E:          00  
    0x0F:          00  

    -- SECTION: input
    0x10:          05  
    0x11:          06  
    0x12:          05  
    0x13:          06  
    0x14:          08  
    0x15:          00  
    0x16:          00  
    0x17:          00  
    0x18:          00  
    0x19:          00  
    0x1A:          00  
    0x1B:          00  
    0x1C:          00  
    0x1D:          00  
    0x1E:          00  
    0x1F:          00  

    -- SECTION: code
    -- start of program, load inputs and add
    0x20: _start:  F1  PFIX  1  -- these 2 are "LDAM 0x10"
    0x21:          00  LDAM  0  
    0x22:          F1  PFIX  1  -- these 2 are "LDBM 0x11"
    0x23:          11  LDBM  1  
    0x24:          D0  ADD   0  
    0x25:          F1  PFIX  1  -- these 2 are "LDBM 0x12"
    0x26:          12  LDBM  2  
    0x27:          D0  ADD   0  
    0x28:          F1  PFIX  1  -- these 2 are "LDBM 0x13"
    0x29:          13  LDBM  3  
    0x2A:          D0  ADD   0  
    0x2B:          F1  PFIX  1  -- these 2 are "LDBM 0x14"
    0x2C:          14  LDBM  4  
    0x2D:          D0  ADD   0

    -- set up parameters and call _div  
    0x2E:          21  STAM  1  -- dividend: sum so far
    0x2F:          35  LDAC  5  -- divisor: 5
    0x30:          22  STAM  2
    0x31:          54  LDAP  4  -- return address
    0x32:          20  STAM  0  
    0x33:          F4  PFIX  4  -- these 3 instructions are "GOTO _div"
    0x34:          40  LDBC  0  
    0x35:          C0  BRB   0  

    -- returned, quotient is in 0x03 and remainder in 0x04
    -- if rem > 0, add 1 to quotient
    0x36:          04  LDAM  4  -- LDAM remainder
    0x37:          A4  BRZ   4  -- BRZ is0
    0x38:          03  LDAM  3  -- LDAM quotient
    0x39:          41  LDBC  1  
    0x3A:          D0  ADD   0  
    0x3B:          23  STAM  3  -- STAM quotient
    0x3C: is0:     03  LDAM  3  -- LDAM quotient
                                --   (if rem=0 we haven't loaded it yet)
    -- HALT
    0x3D:          FF  PFIX  F  
    0x3E:          9E  BR    E

    -- unused  
    0x3F:          00  LDAM  0
  
    -- division function
    -- inputs: 0x00 return address,
    --         0x01 dividend,
    --         0x02 divisor
    -- output: 0x03 quotient
    --         0x04 remainder
    0x40: _div:    30  LDAC  0  
    0x41:          23  STAM  3  -- STAM quotient
    0x42: loop:    01  LDAM  1  -- LDAM dividend
    0x43:          12  LDBM  2  -- LDBM divisor
    0x44:          E0  SUB   0  
    0x45:          F0  PFIX  0  -- these 2 are "BRN endloop"
    0x46:          B7  BRN   7  
    0x47:          21  STAM  1  -- STAM dividend
    0x48:          03  LDAM  3  -- LDAM quotient
    0x49:          41  LDBC  1 
    0x4A:          D0  ADD   0  
    0x4B:          23  STAM  3  -- STAM quotient 
    0x4C:          FF  PFIX  F  -- these 2 are "BR loop"
    0x4D:          94  BR    4  
    0x4E: endloop: 01  LDAM  1  -- LDAM dividend
    0x4F:          24  STAM  4  -- STAM remainder
    0x50:          10  LDBM  0  -- these 2 are "RETURN" with the return address
    0x51:          C0  BRB   0  --   at 0x00


