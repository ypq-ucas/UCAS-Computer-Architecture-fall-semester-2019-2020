Author：赵鑫浩，康齐瀚

lab7_63.pdf 是本次实验的实验报告，myCPU是本次实验的最终提交代码。

---

## myCPU

增加了bltz,jalr等跳转指令和lb,lh,lwl,sb,sh等访存指令的五级流水线CPU

### ID_stage.v

增加了inst_jalr，inst_lb等信号用于新增加指令的判断，增加了load_op等信号的位数用于在EXE级和MEM级获得访存指令的具体类型

### EXE._stage.v

增加了对新的store型指令的支持，修改了data_sram_wen和data_sram_wdata的赋值逻辑

### MEM_stage.v

增加了对新的load型指令的支持，根据访存地址的低两位修改了mem_result的具体赋值