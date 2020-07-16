`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       38
    //`define FS_TO_DS_BUS_WD 64
    `define FS_TO_DS_BUS_WD 71  // plus one for excpetion signal, and 5 bits for excode
    //`define DS_TO_ES_BUS_WD 221
    `define DS_TO_ES_BUS_WD 242
    //`define ES_TO_MS_BUS_WD 117
    `define ES_TO_MS_BUS_WD 137
    //`define MS_TO_WS_BUS_WD 70
    `define MS_TO_WS_BUS_WD 90
    `define WS_TO_RF_BUS_WD 39
    `define CR_STATUS       12
    `define CR_CAUSE        13
    `define CR_EPC          14
`endif
