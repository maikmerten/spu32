 OUTPUT_ARCH( "riscv" )
 ENTRY( _start )
 SECTIONS
 {
 /* text: test code section */
/*  . = (4*1024);*/
  . = ((512 - 32) * 1024);
  .text :
 {
    *(.text.bios_isr)
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
