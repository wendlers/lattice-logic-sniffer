Simple Logic Sniffer for Lattice MachXO2 Breakout Board
=======================================================
09.06.2015 Stefan Wendler
sw@kaltpost.de

This project provides a very simple 8 port logic sniffer written in Verilog for the Lattice MachXO2 Breakout Board. 
Currently also a simple Python API is available to control the logic sniffer through its on board USB port. 

The main features of the logic sniffer ar so far:

* 8 input ports
* up to 48MHz sampling rate
* 16KB sample buffer (using FPGA EBR)
* serial interface through on board FTDI for control at 921600 Baud
* support for simple trigger masks
* configurable sample cock

The Python API supports the following:

* configure sample clock (48MHz to 800Hz)
* configure trigger
* start sampling (with or without trigger) and download samples
* write raw samples
* write samples in VCD (value change definition) for use with GTKWave
* write samples in Sigrok format vor use with Pulseview


Project Directory Layout
------------------------

The top-level directory structure of the project looks something like this:

* `README.md`		This README
* `LICENSE`			The license which applies to the sources of this project (if nothing else is stated in the source files itself!)
* `api`			 	APIs to access the LogicSniffer, currently only the beginning of a Python API	
* `logic`			Verilog code for the FPGA 


Requirements
------------

To build and run the Logic:

* [Lattice MachXO2 breakout board] (http://www.latticesemi.com/en/Products/DevelopmentBoardsAndKits/MachXO2BreakoutBoard.aspx) (very afordable)
* [Lattice Diamond Software] (http://www.latticesemi.com/Products/DesignSoftwareAndIP/FPGAandLDS/LatticeDiamond.aspx), free license available (Installing this on Ubuntu is pain in the ass. But if you really like to do this, let me know and I could provide instructions)

To use the Python API:

* Python 2.7
* To write the Sigrok fromat, [sigrok-cli] (http://sigrok.org/wiki/Sigrok-cli) is needed
* To view VCD, [GTKWave] (http://gtkwave.sourceforge.net/) is needed
* To view Sigrok, [Pulseview] (http://sigrok.org/wiki/PulseView) is needed
 

Build the Logic for the MachXO2
-------------------------------

Open `sniffer.ldf` from the `logic` subdirectory in Diamond. On the left side swich to "Process" tab, right klick "JEDEC File/Rerun All".  
Then flash it to the FPGA by starting the programmer (Tools/Programmer).


Using the Python API
--------------------

The API currently is poorly documented. Some example usage could be found in `api/python/LogicSniffer.py`at the end.

To sample without trigger and save the samples as VCD, the following could be done:

	from LogicSniffer import *

	# we use the UART IO driver to the Lattice
	rio = RegIoUartDriver('/dev/ttyUSB1')

	# and we need the low-level sniffer driver ...
	lsd = LogicSnifferDriver(rio)

	# ... to build the logic sniffer high-level interface
	lsn = LogicSniffer(lsd)
	
	# begin sampling 
	lsn.sample()

	# write samples to VCD file which could be opend e.g. in GTKWave
	lsn.write_vcd('test.vcd')

Or sample at 10KHz and trigger sampling as soon as port 0 goes to high, write Sigrok file:

	from LogicSniffer import *

	rio = RegIoUartDriver('/dev/ttyUSB1')
	lsd = LogicSnifferDriver(rio)
	lsn = LogicSniffer(lsd)

	# set sample clock
	lsn.sample_clock = 10 * KHz

	# set trigger (first param is the mask, second the value)
    lsn.trigger = (0x01, 0x01)

	# begin sampling on trigger
	lsn.sample(use_trigger=True)

	# write samples to Sigrok file which could be opend e.g. in Pulseview 
	lsn.write_sr('test.sr')

