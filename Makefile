
SOURCE_FILES := $(wildcard rtl/*.sv)
TOP = ibex_demo_system

synthesize:
	yosys -p "read_verilog  -formal -sv $(SOURCE_FILES); synth; write_verilog $(TOP)_out.v"

clean:
	rm *.log *.txt *.json *.v