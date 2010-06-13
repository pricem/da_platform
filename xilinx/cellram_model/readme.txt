Disclaimer of Warranty:
-----------------------
This software code and all associated documentation, comments or other 
information (collectively "Software") is provided "AS IS" without 
warranty of any kind. MICRON TECHNOLOGY, INC. ("MTI") EXPRESSLY 
DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
TO, NONINFRINGEMENT OF THIRD PARTY RIGHTS, AND ANY IMPLIED WARRANTIES 
OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. MTI DOES NOT 
WARRANT THAT THE SOFTWARE WILL MEET YOUR REQUIREMENTS, OR THAT THE 
OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. 
FURTHERMORE, MTI DOES NOT MAKE ANY REPRESENTATIONS REGARDING THE USE OR 
THE RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS CORRECTNESS, 
ACCURACY, RELIABILITY, OR OTHERWISE. THE ENTIRE RISK ARISING OUT OF USE 
OR PERFORMANCE OF THE SOFTWARE REMAINS WITH YOU. IN NO EVENT SHALL MTI, 
ITS AFFILIATED COMPANIES OR THEIR SUPPLIERS BE LIABLE FOR ANY DIRECT, 
INDIRECT, CONSEQUENTIAL, INCIDENTAL, OR SPECIAL DAMAGES (INCLUDING, 
WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, BUSINESS INTERRUPTION, 
OR LOSS OF INFORMATION) ARISING OUT OF YOUR USE OF OR INABILITY TO USE 
THE SOFTWARE, EVEN IF MTI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH 
DAMAGES. Because some jurisdictions prohibit the exclusion or 
limitation of liability for consequential or incidental damages, the 
above limitation may not apply to you.

Copyright 2003 Micron Technology, Inc. All rights reserved.

Getting Started:
----------------
Unzip the included files to a folder.
Point your simulator to the folder where you located the files.
Compile cellram.v and tb.v in a verilog simulator.
Simulate the top level test bench tb.
If you are using the ModelSim simulator, type "do tb.do" at the command 
prompt.

File Descriptions:
------------------
cellram.v              --cellram model 
cellram_parameters.vh  --File that contains all parameters used by the model
readme.txt             --This file
tb.v                   --Test bench
subtest.vh             --Test included by the test bench.
tb.do                  --File that compiles and runs the above files

Defining the Speed Grade:
-------------------------
The verilog compiler directive "`define" may be used to choose between 
multiple speed grades supported by the cellram model.  Allowable speed 
grades are listed in the cellram_parameters.v file and begin with the 
letters "sg".  The speed grade is used to select a set of timing 
parameters for the cellram model.  The following are examples of defining 
the speed grade.

    simulator   command line
    ---------   ------------
    ModelSim    vlog +define+sg708 cellram.v
    VCS         vcs +pathpulse +define+sg708 cellram.v
    NC-Verilog  ncverilog +pathpulse +define+sg708 cellram.v

Allocating Memory:
------------------
An associative array has been implemented to reduce the amount of 
static memory allocated by the cellram model.  Each entry in the 
associative array is one data transfer in size.  The number of entries 
in the associative array is controlled by the MEM_BITS parameter, and 
is equal to 2^MEM_BITS.  For example, if the MEM_BITS parameter is 
equal to 10, the associative array will be large enough to store 1024 
writes to unique addresses.  The following are examples of setting the 
MEM_BITS parameter to 8.

    simulator   command line
    ---------   ------------
    ModelSim    vsim -GMEM_BITS=8 cellram
    VCS         vcs -pvalue+MEM_BITS=8 cellram.v
    NC-Verilog  ncverilog +defparam+cellram.MEM_BITS=8 cellram.v
