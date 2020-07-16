`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       38
    //`define FS_TO_DS_BUS_WD 64
    `define FS_TO_DS_BUS_WD 103  // plus one for excpetion signal, and 5 bits for excode
    //`define DS_TO_ES_BUS_WD 221
    `define DS_TO_ES_BUS_WD 280
    //`define ES_TO_MS_BUS_WD 117
    `define ES_TO_MS_BUS_WD 175
    //`define MS_TO_WS_BUS_WD 70
    `define MS_TO_WS_BUS_WD 128
    `define WS_TO_RF_BUS_WD 39
    `define CR_STATUS       12
    `define CR_CAUSE        13
    `define CR_EPC          14
    `define EX_ADEL        5'b00100
    `define EX_ADES        5'b00101
    `define EX_OVERFLOW    5'b01100
    `define EX_SYSCALL     5'b01000
    `define EX_BREAK       5'b01001
    `define EX_RESERVED    5'b01010
    `define CR_COMPARE     8'b01011000
    `define CR_COUNT       8'b01001000
    `define CR_BADVADDR    8'b01000000
`endif

