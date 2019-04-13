---
layout: post
title: Initial RTL Implementation
---

The initial implementation of the N1 processer is complete. The RTL is still unverified. 
Here are the first synthesys results with [Yosys](https://github.com/cliffordwolf/yosys) using the iCE40 library:

<table>
  <tr>
    <th></th>
    <th colspan="2">N1</th>
    <th>J1</th>
  </tr>
  <tr>
    <th></th>    
    <th>in "default" configuration</th>
    <th>in "iCE40UP5K" configuration</th>
    <th>from <a href="https://github.com/igor-m/UPduino-Mecrisp-Ice-15kB">UPduino-Mecrisp-Ice-15kB</a> project</th>
  </tr>
  <tr><td> Number of wires            </td><td> 3123                               |</td><td> 1900 </td><td>   615 </td></tr>
  <tr><td> Number of wire bits        </td><td> 6131                               |</td><td> 5383 </td><td>  3091 </td></tr>
  <tr><td> Number of public wires     </td><td>  341                               |</td><td>  398 </td><td>    47 </td></tr>
  <tr><td> Number of public wire bits </td><td> 3265                               |</td><td> 3881 </td><td>  2441 </td></tr>
  <tr><td> Number of cells            </td><td> 3432                               |</td><td> 2132 </td><td>  2843 </td></tr>
  <tr><td> SB_CARRY                   </td><td>   79                               |</td><td>      </td><td>    80 </td></tr>
  <tr><td> SB_DFFE                    </td><td>                                    |</td><td>      </td><td>  1024 </td></tr>
  <tr><td> SB_DFFER                   </td><td>  423                               |</td><td>  423 </td><td>    16 </td></tr>
  <tr><td> SB_DFFES                   </td><td>   19                               |</td><td>   19 </td><td>       </td></tr>
  <tr><td> SB_DFFESR                  </td><td>                                    |</td><td>      </td><td>    16 </td></tr>
  <tr><td> SB_DFFESS                  </td><td>                                    |</td><td>      </td><td>    16 </td></tr>
  <tr><td> SB_DFFR                    </td><td>    1                               |</td><td>    1 </td><td>    26 </td></tr>
  <tr><td> SB_LUT4                    </td><td> 2910                               |</td><td> 1685 </td><td>  1664 </td></tr>
  <tr><td> SB_MAC16                   </td><td>                                    |</td><td>    4 </td><td>     1 </td></tr>
</table>


The "default" configuration of the N1 processor maps all logic to regular PLBs (programmable logic blocks),
whereas in the "iCE40UP5K" configuration all adders and multipliers are mapped to four "SB_MAC16" DSP cells.

The cell usage of the N1 compares quite well to the J1, but the N1 seems to require a lot more signal routing. 
