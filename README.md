# SECD Abstract Machine in C3

## Notes
- Serialize to array, write array to file

### Control flow
- instruction data structures in array have:
    - function pointer to operation
    - arg1: index of first argument 
    - arg2: index of second argument
        - since we know in advance whether instructions take arguments or not, we don't need to worry about these being empty, since we will handle empty/incorrect arguments during compilation

- alternative oper structure: BitStruct
    - only need 4 bits to refer to function pointer in a global array, which doubles as the ID of the operation
    - then however many bits is required to specify the indices of arguments
    - maybe also store index of next instruction?
    - if syntax is that all operation+arguments are wrapped in (): 
        (LDC 15), then we get the index of the following for free
     - would need a sort of weird iteration to set indices
        - maybe reverse iterate over data structures and expand lists?
        - potentially: 
            - serialize top-level instructions
            - serialize top-level instructions in their arguments
            - etc, or potentially in reverse
                - may need to be in reverse
                - an instruction needs to know the location of its 
                    arguments and the next instruction to execute 
                    after its done
                - so may need to serialize from the bottom, and 
                    from last to first
                - when we write out the arguments of a given oper,
                    we will store the indices of their location as
                    an associated value in the operation itself
                - we really only need the bit-pattern for the oper
                    to be recognized in the high-level representation
                ```
                (LDC 1) 
                (LDC 2) 
                (LDF 
                  (
                    (LD 
                      (1 1))
                    (LD
                      (1 2))
                    (ADD)
                    (RET))
                    )
                (AP)
                ```
                - would be serialized as:
                ```
                (1 2)
                (1 1)
                (RET)
                (ADD)
                (LD)
                (LD)
                (1)
                (2)
                (AP)
                (LDF)
                (LDC)
                (LDC)
                ```

            

- need an initial pass to parse input and set next-instruction for LIST markers
- then a pass to set references for named function definitions


- retain LIST in instructions, but as a marker that stores the first instruction after the list
    - so for LDF
        - the index of the first instruction in the function is pushed to the stack
        - the instruction pointer is set to the index of the next instruction after the function definition (retrieved from the LIST marker at its beginning)
    - for SEL
        - get start of second list from first list
        - get instruction after condition executes from second list
- don't want to have to redefine functions every time they need to be called
    - add instructions 'NAME and #NAME
    - 'NAME takes a function definition as an argument, and afterwards we can refer to the function by using "LDF #NAME" to push a named function to the stack as with LDF

- would also want I/O, so need some of:
    - (PUTC char)/(GETC) operations
    - (SYSCALL (int vargs)) for making system calls
