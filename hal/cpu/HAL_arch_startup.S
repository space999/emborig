#include "../include/vh_cpu_hal.h"

.extern VPOS_kernel_main
.extern vk_undef_handler
.extern vh_hwi_classifier
.extern vk_swi_classifier
.extern vk_pabort_handler
.extern vk_dabort_handler
.extern vk_fiq_handler
.extern vk_not_used_handler
.extern vk_irq_test

.extern vk_sched_save_tcb_ptr

.global vh_VPOS_STARTUP

.global vk_save_swi_mode_stack_ptr		
.global vk_save_swi_current_tcb_bottom
.global vk_save_irq_mode_stack_ptr	
.global vk_save_irq_current_tcb_bottom
.global vk_save_pabort_current_tcb_bottom

.global vh_restore_thread_ctx
.global vh_save_thread_ctx
.global vh_save_ctx_bottom

.equ vh_USERMODE,   0x10
.equ vh_FIQMODE,    0x11
.equ vh_IRQMODE,    0x12
.equ vh_SVCMODE,    0x13
.equ vh_ABORTMODE,  0x17
.equ vh_UNDEFMODE,  0x1b
.equ vh_MODEMASK,   0x1f
.equ vh_NOINT,      0xc0  

.equ vh_userstack,  0x21200000
.equ vh_svcstack,   0X21400000
.equ vh_irqstack,   0x21600000
.equ vh_abortstack, 0x21800000
.equ vh_undefstack, 0x21a00000
.equ vh_fiqstack,   0x21c00000

.equ vh_vector_base, 		0x20008044// relocated vector table base address
.equ vh_VICBASE,		0xe4000000

.text
vh_VPOS_STARTUP:
	/* Camouflaged code for imitating linux
	   Linux has a header that includes 8 nop operation, branch code, magic number, binaray file start offset, and file size(end offset */
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	b 	vh_VPOS_reset
	magicn:	.long 0x016f2818	// Linux magic number
	startn:	.long 0x00000000	// start address(offset) is 0
	endn:	.long 0x0000d8fc	// end address(offset) is file size(byte)
	/* Camouflaged code end */
	
	nop
	nop
	nop
	nop
vh_vector_start:
	b       vh_VPOS_reset                           
        b       vk_undef
        b       vh_software_interrupt   
        b       vh_pabort
        b       vk_dabort
        b       vk_not_used_handler             
        b       vh_irq                  
        b       vk_fiq_handler
vh_VPOS_reset:
	// variable initialization
	mov	r0, #0x00
	str	r0, vk_save_swi_mode_stack_ptr
	str	r0, vk_save_swi_current_tcb_bottom
	str	r0, vk_save_irq_mode_stack_ptr
	str	r0, vk_save_irq_current_tcb_bottom

	// Mask interrupt and fast interrupt

        
	
	// Invalidate all instruction caches to point of unification. Also flushes branch target cache.
	
	// Control Register Setting
	
	
	// change vector table base address (0x20008044)
	
	// stack pointer setting
	mrs r0,cpsr
	
	bic r0,r0,#vh_MODEMASK|vh_NOINT
    	orr r1,r0,#vh_UNDEFMODE|vh_NOINT
    	msr cpsr_cxsf,r1                
    	ldr sp,=vh_undefstack
    
    	bic r0,r0,#vh_MODEMASK|vh_NOINT
    	orr r1,r0,#vh_ABORTMODE|vh_NOINT
    	msr cpsr_cxsf,r1               
    	ldr sp,=vh_abortstack
	
    	bic r0,r0,#vh_MODEMASK|vh_NOINT
    	orr r1,r0,#vh_IRQMODE|vh_NOINT
    	msr cpsr_cxsf,r1              
    	ldr sp,=vh_irqstack

    	bic r0,r0,#vh_MODEMASK|vh_NOINT
    	orr r1,r0,#vh_FIQMODE|vh_NOINT
    	msr cpsr_cxsf,r1             
    	ldr sp,=vh_fiqstack

	bic r0,r0,#vh_MODEMASK|vh_NOINT
    	orr r1,r0,#vh_SVCMODE|vh_NOINT
    	msr cpsr_cxsf,r1            
  	ldr sp,=vh_svcstack	

	// user mode sp 

	b VPOS_kernel_main

.global	vt_read_sp
vt_read_sp:	
	mov	r0,sp
	mov	pc, lr

.global vt_read
vt_read:
	mrs 	r0, cpsr
	mov	pc, lr

vk_undef:
	str	lr, vk_error_addr
        b       vk_undef_handler       

vk_dabort:
	str	lr, vk_error_addr
        b       vk_dabort_handler

.global vh_svc_int_enable
vh_svc_int_enable:
	mrs	r0, cpsr_all
	bic	r0, r0, #0x80
	msr	cpsr_all, r0
	bx	lr




vh_software_interrupt:
vh_entering_swi:
	
	bl	vk_swi_classifier

vh_leaving_swi:



vh_irq:	
vh_irq_VIC0:

vh_irq_VIC1:




vh_pabort:	
    	ldr 	sp,=vh_abortstack

	sub	lr, lr, #4
	str	sp, vk_save_pabort_stack_ptr
	stmfd	sp!, {r0-r14}^
	mrs	r0, spsr_all
	stmfd	sp!, {r0, lr}
	str	sp, vk_save_pabort_current_tcb_bottom
	
	bl	vk_pabort_handler

vh_leaving_pabort:
	ldmfd	sp!, {r0, lr}
	msr	spsr_all, r0
	ldmfd 	sp!, {r0-r12}^
	ldmfd	sp, {r13}^
	add	sp, #4
	ldmfd	sp!, {lr}^
	
	movs	pc, lr

vh_restore_thread_ctx:
	mov	sp, r0   				// sp <- tcb_bottom 

	/*	restore thread psr(r0) and thread address for restart(lr) */
	ldmfd	sp!, {r0, lr}
	msr	spsr_all, r0				// set spsr (current thread psr)

	/* 	restore current thread context.
		we cannot multiple load r13 in Cortex-A9.*/
	ldmfd	sp!, {r0-r12}	
	ldmfd 	sp, {r13}^
	add	sp, #4		
	ldmfd	sp!, {lr}^
	
	ldr	sp, vk_save_swi_mode_stack_ptr
	movs	pc, lr


.global vr_save_thread_ctx
vr_save_thread_ctx:
	ldr	r2, vk_save_pabort_current_tcb_bottom
	b	vh_save_ctx_bottom

.global vh_change_ctx
vh_change_ctx:
	mov	r2, r0
	ldr	r0, vk_save_swi_current_tcb_bottom
	b	vh_save_ctx_bottom

// this function copy data from r2 to r0
vh_save_thread_ctx:
	/*	Check mode */
	mrs	r1, cpsr_all
	bic	r1, r1, #0xfffffff0
	mov	r2, #0x2		// IRQ mode /// modifying
	cmps	r1, r2

	ldreq	r2, vk_save_irq_current_tcb_bottom
	//ldrne	r2, vk_save_swi_current_tcb_bottom
	ldrne	r1, =vk_sched_save_tcb_ptr
	ldrne	r2, [r1]
	
	b	vh_save_ctx_bottom

vh_save_ctx_bottom:
	.rept	17 					// copy context from SVC stack to USER stack
	ldr	r1, [r2], #4
	str	r1, [r0], #4
	.endr
	mov	pc, lr					// return to caller


vk_save_swi_mode_stack_ptr:	
				.long 0
vk_save_swi_current_tcb_bottom:
				.long 0
vk_save_irq_mode_stack_ptr:	
				.long 0
vk_save_irq_current_tcb_bottom:
				.long 0
vk_save_pabort_stack_ptr:	
				.long 0
vk_save_pabort_current_tcb_bottom:
				.long 0

.global vk_error_addr
vk_error_addr:
				.long 0
