MEMORY
{
  flash (rx) : ORIGIN = 0x0000, LENGTH = 32K
  ram (rw!x) : ORIGIN = 0x800060, LENGTH = 2K
}

SECTIONS
{
  .text :
  {
    *(.text*)
    *(.rodata*)
  } > flash

  .data :
  {
    *(.data*)
  } > ram AT > flash

  .bss :
  {
    *(.bss*)
  } > ram
}
