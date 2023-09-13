Stacks
======

We've seen how we can split a program up into functions - small blocks of code
that do exactly one thing and do it well. This makes it much easier to think
about, create, test and debug our functions one at a time and then we can
combine them into a larger program.

We need to make sure we don't waste memory though. If we give each function its
own block of memory for temporary variables, then if we have 100 functions that's
100 blocks of memory we need to find even if we're only ever using one or two
functions at a time. Worse still, we can't use recursion: a function can't call
itself otherwise both copies of the function would use the same block of memory.

But in C we can do multiplication like this. The idea is that `x*y = x+x+x...`
repeating `y` times, so `x*y = x + x*(y-1)`. This algorithm is much easier to
write if `mul` can call itself in the last line.

    uint mul(uint x, uint y) {
        if (y == 0) { return 0; }
        else if (y == 1) { return x; }
        else { return x + mul(x, y-1); }
    }

This is possible because C uses a stack for local variables (and return
addresses). Whenever you call a function, the program code finds some new space
on the stack and gives the function that space to work with. This way, however
many functions you have, only the ones that you are currently using take up
stack space - and functions can call themselves. The one thing that's slightly
more complicated is that functions can't use their own fixed addresses for local
variables anymore, but must compute where they go relative to the current stack.

Stack pointers
--------------

Most processors support stacks through a dedicated stack register and ISA
operations such as `PUSH` and `POP` that work with the stack register. The stack
on the x86 grows downwards instead of upwards, so a `PUSH x` does the following:

  * decrease the stack register by the correct size to hold `x`
  * move `x` to where the stack register currently points (an indirect store)

The x86 `PUSH` operation can take many kinds of operands, including both
constants and register names and byte, word or double-word length specifiers.

If the stack register `SP` is currently at `0x95`, it means that memory from
`0x90` upwards is occupied by the stack. `PUSH 0x10` (a byte constant) first
decreases the stack pointer one byte to `0x94`, then stores the constant `0x10`
at memory location `0x94`.

`POP` takes a register operand and does the opposite of `PUSH`. If our stack
pointer is at `0x94` then `POP al` (`al` is the name of a byte register on the
x86) copies one byte from memory location `0x94` to the `al` register and
increases the stack register to `0x95`.

Functions and stacks
--------------------

To call a function on the x86, generally one uses a convention like the
following (the exact convention depends on the programming language, and even
within C there are different conventions because different operating systems do
things different ways).

  1. If necessary, push the current registers onto the stack, since the function
     may have to use them itself so their current values will get overwritten.
  2. Load the function arguments, either into registers or push them on the stack
     (it is part of a function's definition/documentation which option to use, or
     the programming language may define this for all its functions).
  3. Push the return pointer onto the stack (on a 32-bit machine this is 4 bytes
     long).
  4. Jump to the start of the function.

On x86, steps 3. and 4. can be done with a single instruction `CALL f` where `f`
is the start address of the function.

Once inside the function, the first thing a function will typically do is `PUSH`
some values to reserve itself some space for temporary variables. This has to
happen within the function as the caller should not need to know how much space
the function needs - if we change a function later on, we don't need to adjust
all the code that calls it. The function can then do its work and when it is
done it first removes all the temporary variables again with some `POP`
operations, then it executes the `RET` instruction which takes no parameters
and does two things: first it removes the return pointer from the stack, then it
jumps to it.

Back in the code that called the function, the first thing to do is usually save
the return value somewhere (typically a function returns this in a register),
then restore the registers if they were saved on the stack before the call. The
stack is now back to how it was before the function was called, and the program
can continue. 

*Note: the real situation is more complicated as there is a stack base pointer*
*(BP) as well as a stack top pointer (SP).*

Stacks on Hex8
--------------

The Hex8 architecture does not have a stack register or PUSH/POP instructions.
We can simulate them as follows.

We pick a memory location to hold the stack pointer, let's say `0x0F`. Then we
need some space for the stack itself, let's say from `0xFF` downwards - so the
stack occupies the upper end of our memory.

When our program starts, before we use the stack the first time we have to
initialise the stack pointer, something like this:

    PFIX F
    LDAC F
    STAM F

This stores the constant `0xFF` at memory location `0x0F`.

To push a value on the stack, we have to do the following. Due to there being
only two registers, both of which we'll need to do the push, let's assume our
value is in memory at address `m`:

    LDAM F  -- get the stack pointer
    LDBC 1  -- subtract 1 from stack pointer
    SUB
    STAM F  -- store it back
    LDBM F  -- load new stack pointer into B
    LDAM m  -- load our value (with PFIX if necessary)
    STAI 0

The final `STAI` stores the value in the A register (our value that we just
loaded) into the memory location pointed to by the B register (the new stack
position).

To pop a value, we increase the stack pointer then fetch the value (which is
now in memory one below the stack pointer) into the A register.

    LDAM F  -- get the stack pointer
    LDBC 1  -- increase by 1
    ADD
    STAM F  -- store it back
    SUB     -- point the A register back at the value (B is still 1)
    LDAI 0  -- and fetch it

Both the push and pop operation described here overwrite the values of both the
A and B registers.

Functions and Stacks in Hex8
----------------------------

We can call a function in Hex8 as follows:

  * push parameters on the stack
  * push the return address on the stack
  * jump to the function start
  * (function executes)
  * pop the return value off the stack
  * pop the return address off the stack  
  * pop the parameters off the stack

For this to work, the function has to do the following:

  * push space on the stack for temporary variables
  * do its work
  * remove the temporary variables again
  * push the return value on the stack
  * jump to the return address

We have made the (admittedly unusual) decision to make it the caller's
responsibility to remove the return address. This is because it is easier to
handle the popping this way when the function has only two registers to work
with. It does not, of course, matter who removes the return address as long as
caller and callee agree on whose responsibility it is and the stack ends up the
same as it was before the function started.

Multiplication example
----------------------

Let's write the multiplication program in Hex8. At the start, we want to jump to
`0x10` to leave the low 16 bytes of memory free for the stack pointer and some
temporary space for the main program.

    0x00: _start:  FF  PFIX F  -- set up stack
                   3F  LDAC F
                   2F  STAM F
                   F1  PFIX 1  -- next 3 jump to 'main'
                   40  LDBC 0
                   C0  BRB
                   00 00       -- some padding
    0x08: data:    03 05       -- the values we want to multiply
                   00 00 00 00 00 00 -- some more padding
    0x10: main:    -- (program starts here)            

In our main program, we want to call the `mul` function (that we'll write later)
so let's fetch them (we know they're at `0x08` and `0x09`) and push them on the
stack.

                   -- push value at 0x08
    0x10: main:    0F  LDAM F
                   41  LDBC 1
                   E0  SUB
                   2F  STAM F
                   1F  LDBM F
                   08  LDAM 8
                   80  STAI 0
                       
                   -- push value at 0x09
                   0F  LDAM F
                   41  LDBC 1
                   E0  SUB
                   2F  STAM F
                   1F  LDBM F
                   09  LDAM 9
                   80  STAI 0
                       
                   -- push return address
                   0F  LDAM F
                   41  LDBC 1
    0x20:          E0  SUB
                   2F  STAM F
                   1F  LDBM F
                   54  LDAP 4  -- this gets the return address into A
                   80  STAI 0
                       
                   -- call the function
                   F4  PFIX 4  -- these 3 call "mul"
                   40  LDBC 0
                   C0  BRB
                   
                   -- we've returned. Pop the return value into memory at 0x0A.
                   0F  LDAM F
                   41  LDBC 1
                   D0  ADD
                   2F  STAM F
                   E0  SUB
                   60  LDAI 0
                   2A  STAM A

                   -- clear the return value and parameters, we can just
                   -- increase the stack pointer by 3
                   0F  LDAM F
    0x30:          43  LDBC 3
                   D0  ADD
                   2F  STAM F
                   
                   -- load the return value back into A
                   0A  LDAM A
                   
                   -- and halt
                   FF  PFIX F
                   9E  BR   E
                   
                   -- more padding
                   00 00 00 00 00 00 00 00 00 00

When the main function halts, the product (`3*5 = 15 = 0x0F`) ends up in the A
register and the stack pointer is back at `0xFF`.

The multiplication function
---------------------------

Let's write the following multiplication function. We've made it a bit simpler
by using a temporary variable `r`.

    function mul(x,y) {
        if y = 0 then { r := 0 }
        else if y = 1 then { r := x }
        else {
            r := mul(x, y - 1)
            r := r + x
        }
        return r
    }

Let's write that multiplication function with labels first, then assemble it.
We'll use `sp` to refer to the stack pointer (it's just the constant 0). The
stack will look like this when the function starts - remember that `x` is pushed
first, then `y`, and the stack grows *downwards*:

          ... (more stack, not ours)
          (parameter x)
          (parameter y)
    sp -> (return address)
          ... (the next thing we push will go here)

But we'll need a temporary variable `r` too, so we start off by moving the stack
pointer one down to make this situation:

          ... (more stack, not ours)
          (parameter x)
          (parameter y)
          (return address)
    sp -> (local variable r)
          ...

Instead of mapping the parameter names `x, y` to absolute memory addresses, we
will use them instead to refer to *offsets* relative to the stack pointer. This
means that `x` will stand for 3 and `y` for 2 and `r` for 0. We'll also use
`return` to stand for 1.
So to get the local variable x, we can do `LDAM sp, LDAI x` which is really just
`LDAM F, LDAI 3` although the former makes it clearer what we mean while we're
writing the program. To write a value `v` to `y`, the code is
`LDAC v, LDBM sp, STAI y`.

               -- create local variable r
      mul:     LDAM sp
               LDBC 1
               SUB
               STAM sp

               -- load input y into A register
               -- normally this is LDAM sp, LDAI y but A already has the sp
               LDAI y
               
               -- compare to 0, if so then branch away
               BRZ  yIS0

               -- ok, it's not 0, check if it's 1 (y is already in A)
               LDBC 1
               SUB
               BRZ  yIS1
               
               -- if we're here then y is greater than 1

               -- decrease sp by 3 to fit in new params and return address
               LDAM sp
               LDBC 3
               SUB
               STAM sp
               -- WARNING, now we've moved the sp our local variables are 3
               -- above where they were before! We'll compensate for this.
               
               -- move x into "new parameter x"
               LDAI x+3  -- this is allowed as long as we evaluate it ourselves
               LDBM sp
               STAI 2    -- location of new x
               
               -- subtract 1 from y, move to new parameter y
               LDAM sp
               LDAI y+3
               LDBC 1
               SUB
               LDBM sp
               STAI 1    -- location of new y
               
               -- the return address (B still holds the sp)
               LDAP 3
               STAI 0    -- offset 0, where the return address goes
               PFIX ?    -- call mul, we'll work out the prefix later
               BR   mul
               
               -- We've returned. The stack is now 4 off as there's a return
               -- value on it too; move that into r.
               LDAM sp
               LDAI 0    -- the return value is at offset 0
               LDBM sp
               STAI r+4
               
               -- and put the stack back to normal
               LDAM sp
               LDBC 4
               ADD
               STAM sp
               
               -- with the stack back to normal, do r = r + x
               LDAM sp
               LDAI r
               LDBM sp
               LDBI x
               ADD
               LDBM sp
               STAI r
               
               -- and go to the end
               BR endmul
               
               -- y is 0, so store 0 into r and go to the end
      yIS0:    LDAC 0
               LDBM sp
               STAI r
               BR   endmul

               -- it's one, store x into r and go to the end
      yIS1:    LDAM sp
               LDAI x
               LDBM sp
               STAI r
               -- we don't need to "BR endmul" here
               -- as it's the next line anyway
               
               -- We want to end up with one more variable on the stack
               -- than when we started, and this should be the return
               -- value r. But that's exactly what we already have!
               -- So all we need to do is get the return address and go there.
      endmul:  LDBM sp
               LDBI return
               BRB

We can now assemble the whole thing. Here is the code with the assembled bytes.


    -- create r
    0x40: mul:      0F  LDAM F  (sp)
    0x41:           41  LDBC 1
    0x42:           E0  SUB
    0x43:           2F  STAM F  (sp)

    -- if y = 0
    0x44:           62  LDAI 2  (y)
    0x45:           F2  PFIX 2  (yIS0)
    0x46:           A5  BRZ  5  (yIS0)

    -- else if y = 1
    0x47:           41  LDBC 1
    0x48:           E0  SUB
    0x49:           F2  PFIX 2  (yIS1)
    0x4A:           A5  BRZ  5  (yIS1)

    -- else
    0x4B:           0F  LDAM F  (sp)
    0x4C:           43  LDBC 3
    0x4D:           E0  SUB
    0x4E:           2F  STAM F  (sp)

    -- mul(x, y-1)
    0x4F:           66  LDAI 6  (x+3)
    0x50:           1F  LDBM F  (sp)
    0x51:           82  STAI 2  (new x)
    0x52:           0F  LDAM F  (sp)
    0x53:           65  LDAI 5  (y+3)
    0x54:           41  LDBC 1
    0x55:           E0  SUB
    0x56:           1F  LDBM F  (sp)
    0x57:           81  STAI 1  (new y)
    0x58:           53  LDAP 3  (new return address)
    0x59:           80  STAI 0  (return address on stack)
    0x5A:           FE  PFIX E  (mul)
    0x5B:           94  BR   4  (mul)
              
    -- r := (return value)
    0x5C:           0F  LDAM F  (sp)
    0x5D:           60  LDAI 0  (return value)
    0x5E:           1F  LDBM F  (sp)
    0x5F:           84  STAI 4  (r+4)
            
    -- clean up after call
    0x60:           0F  LDAM F  (sp)
    0x61:           44  LDBC 4
    0x62:           D0  ADD
    0x63:           2F  STAM F  (sp)

    -- r := r + x
    0x64:           0F  LDAM F  (sp)
    0x65:           60  LDAI 0  (r)
    0x66:           1F  LDBM F  (sp)
    0x67:           73  LDBI 3  (x)
    0x68:           D0  ADD
    0x69:           1F  LDBM F  (sp)
    0x6A:           80  STAI 0  (r)
    0x6B:           98  BR   8  (endmul)

    -- r := 0
    0x6C: yIS0:     30  LDAC 0
    0x6D:           1F  LDBM F  (sp)
    0x6E:           80  STAI 0  (r)
    0x6F:           94  BR   4  (endmul)

    -- r := x
    0x70: yIS1:     0F  LDAM F  (sp)
    0x71:           63  LDAI 3  (x)
    0x72:           1F  LDBM F  (sp)
    0x73:           80  STAI 0  (r)

    -- return
    0x74: endmul:   1F  LDBM F  (sp)
    0x75:           71  LDBI 1  (return)
    0x76:           C0  BRB

And here is our whole program assembled.

    0x00:  FF 3F 2F F1 40 C0 00 00 03 05 00 00 00 00 00 00
    0x10:  0F 41 E0 2F 1F 08 80 0F 41 E0 2F 1F 09 80 0F 41
    0x20:  E0 2F 1F 54 80 F4 40 C0 0F 41 D0 2F E0 60 2A 0F
    0x30:  43 D0 2F 0A FF 9E 00 00 00 00 00 00 00 00 00 00
    0x40:  0F 41 E0 2F 62 F2 A5 41 E0 F2 A5 0F 43 E0 2F 66
    0x50:  1F 82 0F 65 41 E0 1F 81 53 80 FE 94 0F 60 1F 84
    0x60:  0F 44 D0 2F 0F 60 1F 73 D0 1F 80 98 30 1F 80 94
    0x70:  0F 63 1F 80 1F 71 C0

The same again, without addresses for easy copy-pasting into the simulator.

    FF 3F 2F F1 40 C0 00 00 03 05 00 00 00 00 00 00
    0F 41 E0 2F 1F 08 80 0F 41 E0 2F 1F 09 80 0F 41
    E0 2F 1F 54 80 F4 40 C0 0F 41 D0 2F E0 60 2A 0F
    43 D0 2F 0A FF 9E 00 00 00 00 00 00 00 00 00 00
    0F 41 E0 2F 62 F2 A5 41 E0 F2 A5 0F 43 E0 2F 66
    1F 82 0F 65 41 E0 1F 81 53 80 FE 94 0F 60 1F 84
    0F 44 D0 2F 0F 60 1F 73 D0 1F 80 98 30 1F 80 94
    0F 63 1F 80 1F 71 C0

This program is set up so that you can change the inputs in `0x08` and `0x09`
and re-run it, and it will compute the product and place it in `0x0A`.

A stack example on a "real" architecture
========================================

*This section contains advanced material.*

Let's look at an example of the stack in a C program on the x86-64 architecture
(as found in many PCs nowadays).

    int mul(int a, int b) {
        if (b == 0) { return 0; }
        if (b == 1) { return a; }
        return (a + mul(a, b - 1));
    }
    
    int main() {
        int x = 3;
        int y = 5;
        int z = mul(x, y);
        return 1;
    }

Here is the program compiled then disassembled using intel syntax:

    1       int mul(int a, int b) {
    0x0000000000400474 <+0>:      55             push   rbp
    0x0000000000400475 <+1>:      48 89 e5       mov    rbp,rsp
    0x0000000000400478 <+4>:      48 83 ec 10    sub    rsp,0x10
    0x000000000040047c <+8>:      89 7d fc       mov    DWORD PTR [rbp-0x4],edi
    0x000000000040047f <+11>:     89 75 f8       mov    DWORD PTR [rbp-0x8],esi
    
    2           if (b == 0) { return 0; }
    0x0000000000400482 <+14>:     83 7d f8 00    cmp    DWORD PTR [rbp-0x8],0x0
    0x0000000000400486 <+18>:     75 07          jne    0x40048f <mul+27>
    0x0000000000400488 <+20>:     b8 00 00 00 00 mov    eax,0x0
    0x000000000040048d <+25>:     eb 20          jmp    0x4004af <mul+59>
    
    3           if (b == 1) { return a; }
    0x000000000040048f <+27>:     83 7d f8 01    cmp    DWORD PTR [rbp-0x8],0x1
    0x0000000000400493 <+31>:     75 05          jne    0x40049a <mul+38>
    0x0000000000400495 <+33>:     8b 45 fc       mov    eax,DWORD PTR [rbp-0x4]
    0x0000000000400498 <+36>:     eb 15          jmp    0x4004af <mul+59>
    
    4           return (a + mul(a, b - 1));
    0x000000000040049a <+38>:     8b 45 f8       mov    eax,DWORD PTR [rbp-0x8]
    0x000000000040049d <+41>:     8d 50 ff       lea    edx,[rax-0x1]
    0x00000000004004a0 <+44>:     8b 45 fc       mov    eax,DWORD PTR [rbp-0x4]
    0x00000000004004a3 <+47>:     89 d6          mov    esi,edx
    0x00000000004004a5 <+49>:     89 c7          mov    edi,eax
    0x00000000004004a7 <+51>:     e8 c8 ff ff ff call   0x400474 <mul>
    0x00000000004004ac <+56>:     03 45 fc       add    eax,DWORD PTR [rbp-0x4]
    
    5       }
    0x00000000004004af <+59>:     c9             leave
    0x00000000004004b0 <+60>:     c3             ret
    
    7       int main() {
    0x00000000004004b1 <+0>:      55             push   rbp
    0x00000000004004b2 <+1>:      48 89 e5       mov    rbp,rsp
    0x00000000004004b5 <+4>:      48 83 ec 10    sub    rsp,0x10
    
    8           int x = 3;
    0x00000000004004b9 <+8>:      c7 45 f4 03 00 00 00   mov    DWORD PTR [rbp-0xc],0x3
    
    9           int y = 5;
    0x00000000004004c0 <+15>:     c7 45 f8 05 00 00 00   mov    DWORD PTR [rbp-0x8],0x5
    
    10          int z = mul(x, y);
    0x00000000004004c7 <+22>:     8b 55 f8       mov    edx,DWORD PTR [rbp-0x8]
    0x00000000004004ca <+25>:     8b 45 f4       mov    eax,DWORD PTR [rbp-0xc]
    0x00000000004004cd <+28>:     89 d6          mov    esi,edx
    0x00000000004004cf <+30>:     89 c7          mov    edi,eax
    0x00000000004004d1 <+32>:     e8 9e ff ff ff call   0x400474 <mul>
    0x00000000004004d6 <+37>:     89 45 fc       mov    DWORD PTR [rbp-0x4],eax
    
    11          return 1;
    0x00000000004004d9 <+40>:     b8 01 00 00 00 mov    eax,0x1
    
    12      }
    0x00000000004004de <+45>:     c9             leave
    0x00000000004004df <+46>:     c3             ret

The following points are worth noting:

  * This is a 64-bit architecture, so the addresses that you see are 8 bytes long.
    The program is compiled in such a way that execution begins at 0x00400000.
    Between this starting point up to 0x00400473 is the C startup code which
    sets up things for C programs to work correctly (not disassembled here).
    From 0x00400474-0x004004b0 is the mul function, from 0x004004b1-004004df
    is the main function.
  * There are 8 main registers called ax, bx, cx, dx, si, di, bp and sp. Each of
    these can be used as a 64-bit register with the "r" prefix, as a 32-bit
    register with the "e" prefix or as a 16-bit register without prefix. So
    "rax" is the whole "A" register, "eax" is the low 32 bits of the "A" register
    and "ax" is the low 16 bits. "sp" and "bp" stand for stack pointer and base
    pointer respectively.
  * In Intel syntax, the destination of an operation comes first:
    "mov rbp, rsp" means "rbp = rsp" and "add eax, ebx" means "eax = eax + ebx".
    (In AT&T assembly syntax things are the other way round.)
  * DWORD PTR means "double word pointer", which means that this is a 32-bit
    operation even though we're on a 64-bit processor. (A "machine word" is 16
    bits, which Intel defined back in the day when they were producing 16-bit
    processors.)
  * The stack grows downwards, so "push rbp" is roughly equivalent to this C
    code: `rsp -= 8; mem[rsp] = rbp;`.

Let's look at the code in more detail.

    -- int mul(int a, int b) {
    push rbp                       -- store rbp on the stack (decreases rsp)
    mov rbp, rsp                   -- copy rsp to rbp
    sub rsp, 0x10                  -- allocate 16 bytes on the stack
    mov DWORD PTR [rbp-0x04], edi  -- save edi (function argument a)
    mov DWORD PTR [rbp-0x08], esi  -- save esi (function argument b)

Every C function begins with a preamble that sets up a stack frame for the
function and saves some registers that it will have to restore before it returns.
In this function, we need to save rsp and rbp.

First, the preamble saves the old rbp on the stack, then it copies rsp to rbp.
The compiler has decided that this function needs a stack frame of 16 (0x10)
bytes, so it subtracts this value from rsp to allocate the space. The result is
that rbp points at the *top* of our stack frame and rsp points at the *bottom*.

How do the function parameters get passed to the function? The C convention for
linux says that the first integer arguments go in rdi, rsi, rdx, rcx in that
order. Our function takes two integer arguments so they go in rdi and rsi, but
the C compiler in question treats `int` as a 32-bit type so it uses the edi/esi
parts of these registers only and uses the DWORD PTR modifier to do a 32-bit
copy on to the stack. This leads to a stack frame that looks like this:

             |32 bits|
             +-------+-------+-------+-------+---------------+
    <- down  |       |       |b (esi)|a (edi)|old rbp        |  up ->
             +-------+-------+-------+-------+---------------+
             ^                               ^
             rsp                             rbp

The base pointer is used to reference local variables. The idea is that the
stack pointer can move down and up again if the function needs more space but
the base pointer is fixed throughout the function. Therefore "parameter a" can
always be addressed as [rbp-0x04], meaning "the thing 4 bytes (32 bits) below
the base pointer".

    -- if (b == 0) { return 0; }
    cmp DWORD PTR [rbp-0x08], 0x00
    jne <mul+27>
    mov eax, 0x00
    jmp <mul+59>

The x86 processor series has a "flags" register. The compare instruction sets or
clears these flags. The first instruction in this block compares "the 32 bits
(DWORD PTR) of the thing 8 bytes below the base pointer (i.e. local variable "b")
to the constant zero". This will set or clear the "equals" flag among others.

JNE stands for "jump if not equal" and is a conditional relative jump; in this
case the binary form `75 07` uses the second byte to encode the offset (jump
forwards by 7 bytes). The result is that if b is not zero, we skip the next
couple of instructions and continue with the "if (b == 1)" part. If b is zero,
then the JNE does nothing and we on the next mov instruction. The convention is
that integer return values go in the rax register (eax if it's a 32 bit value)
so to "return 0" we set eax to 0 and jump to the end of the function (JMP is an
unconditional relative jump), where we'll restore the stack and registers.

    -- if (b == 1) { return a; }
    cmp DWORD PTR [rbp-0x08], 0x01
    jne <mul+38>
    mov eax, DWORD PTR [rpb-0x04]
    jmp <mul+59>

Same story again. Compare b to 1, if they're equal then copy the "a" value into
the eax register and jump to the end. If they're not equal, the JNE skips to the
next instruction.

    -- return (a + mul(a, b - 1));
    mov eax, DWORD PTR [rbp - 0x08]  -- put b in eax
    lea edx, [rax - 0x01]            -- trick with lea to put (b-1) in edx
    mov eax, DWORD PTR [rbp - 0x04]  -- put a in eax
    mov esi, edx                     -- copy edx (b-1) to esi (b param for call)
    mov edi, eax                     -- copy eax (a) to edi (a param for call)
    call <mul>                       -- call function
    add eax, DWORD PTR [rbp - 0x04]  -- we're back, add a to result

Here we want to call mul with parameters a and b-1, take the return value (which
will be in the eax register), add a to it and put the result back in the eax
register.

First we put b in the eax register. We could now do a subtraction, but
the compiler has decided that "lea" is slightly faster. This instruction is
"load effective address" but it takes a base/offset pair of arguments that can
be used for addition and subtraction. The result is that edx gets the value b-1.

To call mul with parameters a and (b-1), we copy them into edi/esi and run the
CALL instruction. This pushes the address of the next instruction (the return
address) on to the stack and then jumps to the indicated instruction.

When we return, the result of the call is in eax. The last instruction reads
"add eax to the thing 4 bytes below the bp (which is a) and put the result into
eax again".

    leave
    ret

This is the function's clean-up code. The two JMP instructions earlier jump to
here and the last "return" in the C code falls through to here. LEAVE is an
instruction that does the following two things: `mov rsp, rbp; pop rbp`.
This restores our stack pointer to where it was after the initial push, then
pops the top value on the stack into the base pointer register which both
restores the original base pointer and moves the stack pointer back where it was
before the initial push. The result is that the stack and base pointers are back
where they were when we entered this function.

RET pops a value off the stack into the program counter, thus jumping to it.
CALL and RET complement each other like PUSH/POP: `CALL f` pushes the address of
the next instruction on the stack then jumps to f; `RET` pops an address off the
stack and jumps to it. In other words:

  * `CALL f ~= PUSH (pc + len); MOV pc, f` where `len` is the length of the JMP
    instruction, so we push the address of the instruction after the jump.
  * `RET ~= POP pc`.

You can't actually push/pop/mov with the pc register directly on x86, you can
only access it through jump and call/ret and a few other instructions. On other
architectures like ARM you can access the pc like any other register.

And here is the main function:

    -- preamble
    push rbp                          -- standard preamble: save rbp
    mov rbp, rsp                      -- and set rbp to the top of our frame
    sub rsp, 0x10                     -- reserve 0x10 bytes of stack
    -- int x = 3;
    mov DWORD PTR [rbp - 0x0c], 0x03  -- store 3 in x (x is 0x0c below bp)
    -- int y = 5;
    mov DWORD PTR [rbp - 0x08], 0x05  -- store 5 in y (y is 0x08 below bp)
    -- int z = mul(x, y);
    mov edx, DWORD PTR [rbp - 0x08]   -- copy y into edx
    mov eax, DWORD PTR [rbp - 0x0c]   -- copy x into eax
    mov esi, edx                      -- to call mul we need the parameters in
    mov edi, eax                      -- the edi and esi registers.
    call <mul>                        -- call the function
    mov DWORD PTR [rbp - 0x04], eax   -- return value is in eax, copy into z
    -- return 1
    mov eax, 0x01                     -- "return 1" means put 1 in eax
    leave                             -- clean up the stack
    ret                               -- and return

The compiler has decided to allocate local variables as follows:

    variable  position
    --------  --------
    x         rbp - 0c
    y         rbp - 08
    z         rbp - 04

So the C code `x = 3;` becomes `mov DWORD PTR [rbp - 0x0c], 0x03`, that is "put
the value 3 in memory 0x0c bytes below the bp".

The final RET in main returns to the C loader code which then calls the
operating system to exit the program.
