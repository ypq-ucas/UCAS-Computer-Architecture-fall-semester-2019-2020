Author：赵鑫浩，康齐瀚

Student ID: 2017K8009922032,  2017K8009922026

lab8_63.pdf 是本次实验的实验报告，myCPU是本次实验的最终提交代码。

---

## myCPU

增加了CP0_regfile.v 文件。 增加了对syscall例外的处理以及mfc0，mtc0指令

### IF_stage.v

增加了对取值地址合法性的检查

### ID_stage.v

增加了对syscall的例外处理

### EXE._stage.v

增加了对访存地址的合法性检查以及对溢出的例外处理

### CP0_regfile.v

CP0寄存器模块，增加了对CP0 status， CP0 cause， CP0 epc寄存器的支持