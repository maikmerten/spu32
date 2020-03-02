 OUTPUT_ARCH( "riscv" )
 ENTRY( _start )
 SECTIONS
 {
 /* text: test code section */
 //. = 0x200;
 . = 0x0;
 .text :
 {
 *(.text._start)    
 *(.text)
 }
 /* data: Initialized data segment */
 .data :
 {
 *(.data)
 }
 /* End of uninitalized data segement */
 _end = .;
 }
