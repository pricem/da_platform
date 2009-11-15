
from myhdl import *
from _odict import *


def ValidateRegDef(RegDef):
    pass


def PrintRegDef(RegDef):
    pass

def GetRegisterFile(RegDef):
    """ Generate the list of signals required for the register defintion
    """
    
    rwRegisters = [] # read / write and write-through register file
    rwWr        = [] # wt (rw) write strobes
    rwRd        = [] # rw read strobes
    roRegisters = [] # read only list of signals (pseudo register file)
    roRd        = [] # read only strobes

    # Enforce RegDef is type OrderedDict
    assert isinstance(RegDef, odict)
    
    for k, v in RegDef.iteritems():
        # @todo if register width is greater than 32 error!  Add some checking
        if v['type'] == 'rw' or v['type'] == 'wt':
            rwRegisters.append(Signal(intbv(v['default'])[v['width']:]))
            rwWr.append(Signal(False))
            rwRd.append(Signal(False))
        elif v['type'] == 'ro':
            roRegisters.append(Signal(intbv(0)[v['width']:]))
            roRd.append(Signal(False))
        else:
            raise TypeError, "incorrect register type %s" % (v['type'])

    return rwRegisters, rwWr, rwRd, roRegisters, roRd


## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## @todo The current myhdl "list of signals" (LOS)  is limiting (BOMK) because
##       it wants to default a "list of signals" to a memory structure (blah)
##       so it tries and enforce rules that would apply to a memory, like same
##       bitwidth per signal in the list etc.
##       I would prefer a more general handling of a "list of signals"
##       and a memory is a subset of the LOS usage.  I don't know if it is possible
##       to determine a memory is desired.  The following will fail if the registers
##       are not all the same size.  Do not want this restriction.
##  Suggest solution:
##       In the MyHDL _extractHierarchy where a LOS is added to the memdict add
##       and additional function that determines if the LOS is a memory type
##       (each signal type intbv(), all same width).  If not add new type losdict
##       and add the signal to the losdict.  The conversion _analyze modules will
##       have to be updated to covert the losdict.  This will be a little more
##       difficult, will require the following
##          1.  name expansion, need a unique name for each signal in the list
##          2.  declrations
##          3.  uses (reads and writes).  Basically should be a replace of los[index]
##              with the name expansion.
##
##       It would also be nice if myhdl conversion performed loop unrolling because
##       it would allow the usage of powerful python data structures.  This would
##       be possible becuase the data structures often would equate to a simple
##       constant or signal.  For a constant the literal value is simply used and
##       for a signal a unique name (consitently generated) would be created.  Because
##       the loops are always static (dynamic loops not synthesizable) the unrolling
##       is always possible.  Loops would be more like generate loops but in the end
##       if it is used pre-synthesis or a loop in synthesis it always results to the
##       similar unrolling (?? this might not be true, synthesis tools might do
##       some optimization on loops that isn't done on an unrolled loop??)
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
def GenerateFunc(RegDef, name, opth='./', C_DSZ=8, C_ASZ=16):
    """Generate the register file logic.
    """
    rwRegisters = [] # read / write and write-through register file
    rwAddresses = [] # rw and wt address.  Should be the same size as rwRegisters
    rwWr        = [] # wt (rw) write strobes
    rwRd        = [] # rw read strobes
    rwDefaults  = [] # default values for the rw registers
    roRegisters = [] # read only list of signals (pseudo register file)
    roAddresses = [] # read only address
    roRd        = [] # read only strobes

    # Debug
    rwRegNames  = []
    roRegNames  = []

    # Enforce RegDef is type OrderedDict
    assert isinstance(RegDef, odict)
    
    #print "\n"
    for k, v in RegDef.iteritems():
        # @todo if register width is greater than 32 error!  Add some checking
        if v['type'] == 'rw' or v['type'] == 'wt':
            rwRegisters.append(Signal(intbv(v['default'])[v['width']:]))
            rwAddresses.append(v['addr'])
            rwDefaults.append(v['default'])
            rwWr.append(Signal(False))
            rwRd.append(Signal(False))
            rwRegNames.append(k)
            #print '  -- Register %s Address 0x%08x Number of Bits %d Default 0x%08x' % \
            #  (k, v['addr'], v['width'], v['default'])
        elif v['type'] == 'ro':
            roRegisters.append(Signal(intbv(0)[v['width']:]))
            roAddresses.append(v['addr'])
            roRd.append(Signal(False))
            roRegNames.append(k)
            #print '  -- Register %s Address 0x%08x Number of Bits %d' % \
            #  (k, v['addr'], v['width'])
        else:
            raise TypeError, "incorrect register type %s" % (v['type'])
                
    #print rwRegNames, rwRegisters
    #print roRegNames, roRegisters
    
    low_a  = 0xFFFF
    high_a = 0
    if len(rwAddresses) > 0:
        low_a  = min(low_a,  min(rwAddresses))
        high_a = max(high_a, max(rwAddresses))
    if len(roAddresses) > 0:
        low_a  = min(low_a,  min(roAddresses))
        high_a = max(high_a, max(roAddresses))

    #print "\n"
    RegFileCode =  "from myhdl import *\n"
    RegFileCode += "def %s_RegisterFile(\n" % (name)
    RegFileCode += "        clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,\n"
    RegFileCode += "        sel_i, dat_i, dat_o, ack_o,\n"
    RegFileCode += "        wb_wr, wb_acc, \n"
    RegFileCode += "        rwRegisters, rwWr, rwRd, roRegisters, roRd,"
    RegFileCode += "        C_WB_BASE_ADDR=0x0000):\n\n"
    
    RegFileCode += "    _wb_do  = Signal(intbv(0)[%d:]) \n" % (C_DSZ)
    RegFileCode += "    _wb_sel = Signal(False) \n"
    RegFileCode += "    _wb_acc = Signal(False) \n"
    RegFileCode += "    _wb_wr  = Signal(False) \n"
    RegFileCode += "    _wb_ack = Signal(False) \n\n"
    
    RegFileCode += "    @always_comb\n"
    RegFileCode += "    def rtl_assignments1():\n"
    RegFileCode += "        _wb_acc.next = cyc_i & stb_i \n"
    RegFileCode += "        ack_o.next   = _wb_ack\n\n"

    RegFileCode += "    @always_comb\n"
    RegFileCode += "    def rtl_assignments2():\n"    
    RegFileCode += "        _wb_wr.next  = _wb_acc & we_i \n\n"

    RegFileCode += "    @always_comb\n"
    RegFileCode += "    def rtl_assignments3():\n"    
    RegFileCode += "        wb_wr.next  = _wb_wr \n"
    RegFileCode += "        wb_acc.next = _wb_acc \n\n"

    # Create the code for the register file
    if len(rwRegisters) > 0 or len(roRegisters) > 0:
        RegFileCode += "    @always(clk_i.posedge)\n"
        RegFileCode += "    def rtl_read_reg():\n"

        # Read the Read/Write registers
        # @todo width of the register (len(rwRegister)) > C_DSZ break up
        if len(rwRegisters) > 0:
            RegFileCode += "        if adr_i == (0x%x + C_WB_BASE_ADDR):\n" % (int(rwAddresses[0]))
            RegFileCode += "            _wb_do.next = rwRegisters[%d]\n\n" % (0)
            for r in range(1, len(rwRegisters)):
                RegFileCode += "        elif adr_i == (0x%x + C_WB_BASE_ADDR):\n" % (int(rwAddresses[r]))
                RegFileCode += "            _wb_do.next = rwRegisters[%d]\n\n" % (r)

        # Read the read only signals
        # @todo width of the register (len(rwRegister)) > C_DSZ break up
        if len(roRegisters) > 0:
            RegFileCode += "        elif adr_i == (0x%x + C_WB_BASE_ADDR):\n" % (int(roAddresses[0]))
            RegFileCode += "            _wb_do.next = roRegisters[%d]\n\n" % (0)
            for r in range(1, len(roRegisters)):
                RegFileCode += "        elif adr_i == (0x%x + C_WB_BASE_ADDR):\n" % (int(roAddresses[r]))
                RegFileCode += "            _wb_do.next = roRegisters[%d]\n\n" % (r)
            RegFileCode += "        else:\n"
            RegFileCode += "            _wb_do.next = 0\n\n"


    # @todo checking the address range might not generate the most efficeint
    #       hardware.  Instead An address mask can be generated by taking the
    #       difference between the low and high addresses and calculating the
    #       log2 to find the number of bits to mask.
    RegFileCode += "    @always(clk_i.posedge)\n"
    RegFileCode += "    def rtl_selected():\n"
    RegFileCode += "        if adr_i >= (0x%x + C_WB_BASE_ADDR) and adr_i <= (0x%x + C_WB_BASE_ADDR):\n" % (low_a, high_a)
    RegFileCode += "            _wb_sel.next = True\n"
    RegFileCode += "        else:\n"
    RegFileCode += "            _wb_sel.next = False\n\n"
    
    RegFileCode += "    @always_comb\n"
    RegFileCode += "    def rtl_read():\n"
    RegFileCode += "        if _wb_sel:\n"
    RegFileCode += "            dat_o.next = _wb_do\n"
    RegFileCode += "        else:\n"
    RegFileCode += "            dat_o.next = 0\n\n"

    # @todo do the same optimizaiton as above, determine the number
    #       of bits required to check address.
    # @todo width of the register (len(rwRegister)) > C_DSZ break up
    # @todo if len(rwRegisters) > 0:
    RegFileCode += "    @always(clk_i.posedge)\n"
    RegFileCode += "    def rtl_write_reg(): \n"
    RegFileCode += "        if not rst_i:\n"
    RegFileCode += "            rwRegisters[%d].next = 0x%x \n\n" % (0, rwDefaults[0])    
    for r in range(1, len(rwRegisters)):
            RegFileCode += "            rwRegisters[%d].next = 0x%x \n\n" % (r, rwDefaults[r])    

    RegFileCode += "        elif _wb_wr and _wb_sel: \n"
    RegFileCode += "            if adr_i == (0x%x + C_WB_BASE_ADDR):\n" % (int(rwAddresses[0]))
    RegFileCode += "                rwRegisters[%d].next = dat_i \n\n" % (0)    
    for r in range(1, len(rwRegisters)):
            RegFileCode += "            elif adr_i == (0x%x + C_WB_BASE_ADDR):\n" % (int(rwAddresses[r]))
            RegFileCode += "                rwRegisters[%d].next = dat_i \n\n" % (r)    

    RegFileCode += "    @always(clk_i.posedge)\n"
    RegFileCode += "    def rtl_ack(): \n"
    RegFileCode += "        if not rst_i:\n"
    RegFileCode += "            _wb_ack.next = False\n"
    RegFileCode += "        else:\n"
    RegFileCode += "            _wb_ack.next = _wb_acc & ~_wb_ack\n\n"

    if len(rwRegisters) > 0:
        RegFileCode += "    @always(clk_i.posedge)\n"
        RegFileCode += "    def rtl_rw_stobes(): \n"
        # @todo use address bit mask and _wb_sel not full address compare
        for r in range(len(rwRegisters)):
            RegFileCode += "        if adr_i == (0x%x + C_WB_BASE_ADDR) and _wb_ack: \n" % (rwAddresses[r])
            RegFileCode += "            if _wb_wr: \n"
            RegFileCode += "                rwWr[%d].next = True \n"  % (r)
            RegFileCode += "                rwRd[%d].next = False \n"  % (r)
            RegFileCode += "            else: \n"
            RegFileCode += "                rwWr[%d].next = False \n" % (r)
            RegFileCode += "                rwRd[%d].next = True \n"  % (r)
            RegFileCode += "        else: \n"
            RegFileCode += "            rwWr[%d].next = False \n" % (r)
            RegFileCode += "            rwRd[%d].next = False \n\n"  % (r)


    if len(roRegisters) > 0:
        RegFileCode += "    @always(clk_i.posedge)\n"
        RegFileCode += "    def rtl_ro_stobes(): \n"
        # @todo use address bit mask and _wb_sel not full address compare
        for r in range(len(roRegisters)):
            RegFileCode += "        if adr_i == (0x%x + C_WB_BASE_ADDR) and _wb_ack: \n" % (roAddresses[r])
            RegFileCode += "            if _wb_wr: \n"
            RegFileCode += "                roRd[%d].next = False \n"  % (r)
            RegFileCode += "            else: \n"
            RegFileCode += "                roRd[%d].next = True \n"  % (r)
            RegFileCode += "        else: \n"
            RegFileCode += "            roRd[%d].next = False \n\n"  % (r)

    RegFileCode += "    return instances()"

    #print "---------------------------------------------------------------------------"
    #print RegFileCode
    #print "---------------------------------------------------------------------------"
    # @todo if opth ends in / remove it
    fp = open("%s/%s_register_file.py" % (opth,name), "w")
    fp.write(RegFileCode)
    fp.close
    
    #return rwRegisters, rwWr, rwRd, roRegisters, roRd
    
