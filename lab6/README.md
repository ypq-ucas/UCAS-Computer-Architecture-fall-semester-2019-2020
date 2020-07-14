Author：赵鑫浩，康齐瀚

lab6_63.pdf 是本次实验的实验报告，myCPU是本次实验的最终提交代码。

---

## myCPU

增加了ADDU，ADDIU，ANDI等指令以及乘除法指令和与之配套的数据搬运指令的五级流水线CPU

### ID_stage.v

增加了inst_addu，inst_subu等信号用于指令类型的判断，增加了alu_op等信号的位数用于支持乘除法和算术逻辑移位指令。

### EXE._stage.v

调用了Vivado的除法IP mydiv_signed和mydiv_unsigned用于除法指令的计算。增加了hi, lo两个寄存器信号用于保存乘除法运算结果。