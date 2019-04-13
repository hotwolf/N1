---
layout: post
title: Initial RTL Implementation
---

The initial implementation of the N1 processer is complete. The RTL is still unverified. 
Here are the first synthesys results with [Yosys](https://github.com/cliffordwolf/yosys) using the iCE40 library:

|                          | N1 <br> in "default" Cconfiguration | N1 <br> in "iCE40UP5K" configuration | J1<br> from [UPduino-Mecrisp-Ice-15kB](https://github.com/igor-m/UPduino-Mecrisp-Ice-15kB) project |
-------------------------- | :---------------------------------: | :----------------------------------: | :------------------------------------------------------------------------------------------------: |
Number of wires            |  3123                               | 1900                                 |   615                                                                                              |
Number of wire bits        |  6131                               | 5383                                 |  3091                                                                                              |
Number of public wires     |   341                               |  398                                 |    47                                                                                              |
Number of public wire bits |  3265                               | 3881                                 |  2441                                                                                              |
Number of cells            |  3432                               | 2132                                 |  2843                                                                                              |
SB_CARRY                   |    79                               |                                      |    80                                                                                              |
SB_DFFE                    |                                     |                                      |  1024                                                                                              |
SB_DFFER                   |   423                               |  423                                 |    16                                                                                              |
SB_DFFES                   |    19                               |   19                                 |                                                                                                    |
SB_DFFESR                  |                                     |                                      |    16                                                                                              |
SB_DFFESS                  |                                     |                                      |    16                                                                                              |
SB_DFFR                    |     1                               |    1                                 |    26                                                                                              |
SB_LUT4                    |  2910                               | 1685                                 |  1664                                                                                              |
SB_MAC16                   |                                     |    4                                 |     1                                                                                              |
[Prototype table]


The "default" configuration of the N1 processor maps all logic to regular PLBs (programmable logic blocks),
whereas in the "iCE40UP5K" configuration all adders and multipliers are mapped to four "SB_MAC16" DSP cells.

The cell usage of the N1 compares quite well to the J1, but the N1 seems to require a lot more signal routing. 
