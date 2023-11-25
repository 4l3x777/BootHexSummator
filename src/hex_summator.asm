; BIOS reads 512 bytes from cylinder: 0, head: 0, sector: 1
; of bootable floppy drive, then it loads this data into
; memory at 0000:7c00h and starts the execution from the first byte.

; note: this file is assembled into .bin file.
;       default configuration for .binf file:
;       load segment: 0000, load offset: 7c00, 
;       same values are set to CS and IP registers accordingly.

; .binf file is used by the emulator to decide at what memory
; address to load binary file and start the execution, when 
; loading address is set to 0000:7c00 it emulates the way BIOS
; loads the boot record into the memory.

; the output of this format is identical to format created from
; bin template, both templates create plain binary files.
; .boot output type is outdated because of its redundancy.
; you can write .bin file to boot record of a real
; floppy drive using writebin.asm (it's required to assemble this file first)

; note: you may not use dos interrupts for boot record code,
;       unless you manually replace them in interrupt vector table.
;       (refer to global memory map in documentation)

#make_boot#

org 7c00h      ; boot location.

; main program entry
start:
	; print message1
    lea si, message1
    call print_string
	
	; get first number string
    lea di, first_number
    call get_string
	
	; store input number in little endian format for continue write to FLOOPY_0 1 sector
	mov bx, 1
	lea si, first_number
	lea di, le_first_number
	call little_endian_store  
	
	; print message2
    lea si, message2
    call print_string
	
	; get second number string
    lea di, second_number
    call get_string	
	
	; store input number in little endian format for continue write to FLOOPY_0 2 sector
	mov bx, 2
	lea si, second_number
	lea di, le_second_number
	call little_endian_store 
	
	; print message3
    lea si, message3
    call print_string   
	
	; calculate sum of numbers
    call get_sum	
	
	; print sum
	lea si, le_sum_numbers
	call print_le_hex_string
	
	; write result to FLOOPY_0 3 sector 
	mov cl, 3
	lea bx, le_sum_numbers 
	call write_to_floppy_sector
	
	; exit
    jmp goto_reboot
	
print_le_hex_string:
	xor cx, cx
	mov cl, [sum_length]
	add si, cx
	dec si
print_le_hex_string_loop:
	std
	lodsb
	cmp al, 0x9
	jle decimal_symbol
	add al, 0x7
decimal_symbol:
	add al, 0x30
	call print_symbol
	loop print_le_hex_string_loop
	ret	
	
little_endian_store:
	push bx
	push di
	
	; rewrite from big-endian to little-endian
	inc si
	xor cx, cx
	mov cl, [si]
	add si, cx
loop_big_endian:
	std
  	lodsb
	cld
	stosb
	loop loop_big_endian	
	; write to floppy sector
	pop di
	pop bx
	mov cl, bl ; sector number
	mov bx, di ; buffer to write
write_to_floppy_sector:  
    mov ah, 0x03 	; write operation
    mov al, 1		; number of sectors to write
    mov dh, 0
    mov dl, 0 		; FLOOPY_0
    mov ch, 0
    int 13h
    ret
	
get_sum:
    call get_numbers_from_memory
	
	push di
    push si
	
	lea di, le_sum_numbers ; pointer to the end of the sum number in di
	mov [sum_length], bl
    mov cx, bx
    xor ah, ah
	jmp loop_sum
	
loop_sum:    
    pop si
	cld
    lodsb       
    mov bl, al   
    
    add bl, ah
    xor ah, ah
    
    mov dx, si
    pop si
	cld
    lodsb
    
    push dx
    push si
        
    add al, bl
    
    cmp al, 0x0f  
    jle put_result_byte
    mov ah, 1
    sub al, 0x10 
put_result_byte:   	
    stosb
    loop loop_sum
    
    test ah, ah
    jz loop_sum_ret
    mov al, 1
	cld
    stosb
	; increment sum_length
	mov al, [sum_length]
	inc al
	mov [sum_length], al
loop_sum_ret:
	pop si
	pop si
    ret
	
get_numbers_from_memory:
    lea di, first_number
    inc di
    mov bl, [di] 					; length first number
	lea di, le_first_number
    
    lea si, second_number
    inc si
    mov al, [si] 					; length second number
	lea si, le_second_number
    
    cmp al, bl
    jle get_numbers_from_memory_done
    ; swap storing first number and second number
    lea di, second_number
    inc di
    mov bl, [di] 					; length second number
	lea di, le_second_number
    
    lea si, first_number
    inc si
    mov al, [si] 					; length first number
	lea si, le_first_number
get_numbers_from_memory_done:
    xor ah, ah
	xor bh, bh
    ret  

; print string & print symbol methods	
print_string:
    lodsb
    test al, al
    jz end_of_string
    call print_symbol
    jmp print_string
end_of_string:
    ret	
  
print_symbol:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
    mov ah, 0x02
    inc [column]
    push ax
    mov al, [row_max_length]
    cmp [column], al
    pop ax
    jl  current_row
    mov [column], 0
    inc [row]
current_row:
    mov dh, [row]
    mov dl, [column]    
    int 0x10
    ret
new_row:
    mov ah, 0x2
    inc [row]
    mov [column], 0
    mov dh, [row]
    mov dl, [column]    
    int 0x10
    ret 

; get string from keyboard & parsing hex value methods    
get_string:
    mov cl, [di]
    inc di
    mov bl, [di]
    xor bh, bh
get_string_loop:    
    cmp cl, bl
    je end_get_string
    call get_hex_symbol
    cmp al, 0x0d 		; hex value of 'enter' symbol
    je end_get_string
    
	inc bl
    add di, bx
    mov [di], al
    sub di, bx
    mov [di], bl

    mov al, ah
    mov ah, 0x0e
    int 0x10
	mov ah, 0x02
	inc [column]
	push ax
    mov al, cs:[row_max_length] 
    cmp [column], al
    pop ax
    jl  current_row_2
    mov [column], 0
    inc [row]
current_row_2:
    mov dh, [row]
    mov dl, [column]    
    int 0x10
    jmp get_string_loop 
end_get_string:    
    test bl, bl
    je string_is_empty
	call new_row
    ret	

get_hex_symbol:    
    xor ah, ah
    int 0x16
    cmp al, 0x0d ; hex value of 'enter' symbol
    jne check_symbol_is_esc
	ret
check_symbol_is_esc:
	cmp al, 0x1b ; hex value of 'esc' symbol
	jne check_symbol_is_hex
	jmp good_bye
check_symbol_is_hex:
    mov ah, al
    cmp al, 0x30
    jl symbol_not_a_hex 
    cmp al, 0x39
    jle hex_0_9
    cmp al, 0x41
    jl symbol_not_a_hex
    cmp al, 0x46
    jle hex_upper_a_f
    cmp al, 0x61
    jl symbol_not_a_hex
    cmp al, 0x66
    jle hex_lower_a_f
	jmp symbol_not_a_hex
hex_0_9:
    sub al, 0x30
    ret
hex_upper_a_f:
    sub al, 0x37
    ret
hex_lower_a_f:
    sub al, 0x57
    ret

; errors catching methods	
symbol_not_a_hex:
	call new_row
    lea si, message4
    call print_string
    jmp goto_reboot	
		
string_is_empty:
	call new_row
    lea si, message5
    call print_string
    jmp goto_reboot

good_bye:
	call new_row
    lea si, message6
    call print_string
    jmp goto_reboot		
		
; program data
message1 		db 'Enter the first number: ', 0
message2 		db 'Enter the second number: ', 0
message3 		db 'The sum in hexadecimal is: ', 0
message4 		db 'Error, number is not a hex value', 0
message5 		db 'Error, input string is empty', 0
message6 		db 'Good, bye!', 0

; rewrite to store in first, second and third FLOOPY_0 sectors (512 bytes per sector)
first_number 		db 10         	; buffer max size
					db 00       	; buffer stored size
					db 10 dup(0) 	; buffer	
					
second_number 		db 10         	; buffer max size
					db 00       	; buffer stored size
					db 10 dup(0) 	; buffer				

column 				db 0       		; cursor column

row 				db 0       		; cursor row

row_max_length 		db 0x50			; max symbols printing to screen per row

le_first_number 	db 512 dup(0)	; little endian store number

le_second_number 	db 512 dup(0)	; little endian store number

le_sum_numbers 		db 512 dup(0)	; little endian store number

sum_length			db 0			; sum stored size

; reboot method
goto_reboot:
    int 0x19