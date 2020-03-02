 OUTPUT_ARCH( "riscv" )
 ENTRY( _start )
 SECTIONS
 {
 /* text: test code section */
  . = (512 - 40) * 1024;
  .text :
 {
    *(.text._start)
    *(.text*)
 }
 /* data: Initialized data segment */
 .data :
 {
    *(.data)
 }
 /* End of uninitalized data segement */
 _end = .;
 }
