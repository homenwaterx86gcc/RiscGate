
IBEX_FILES := ibex_pkg.sv ibex_alu.sv ibex_compressed_decoder.sv ibex_csr.sv ibex_controller.sv \
					ibex_counter.sv ibex_cs_registers.sv ibex_decoder.sv ibex_ex_block.sv ibex_wb_stage.sv \
					ibex_id_stage.sv ibex_if_stage.sv ibex_load_store_unit.sv ibex_multdiv_slow.sv \
					ibex_multdiv_fast.sv ibex_prefetch_buffer.sv ibex_fetch_fifo.sv ibex_register_file_ff.sv \
					ibex_core.sv
SOURCE_FILES := $(addprefix rtl/, $(IBEX_FILES))
TOP = ibex_core

synthesize:
	yosys -m slang -ql synth_log.txt -p "read_slang -v $(SOURCE_FILES); synth_gatemate -top $(TOP) -luttree -nomx8; write_verilog $(TOP)_netlist.v"

clean:
	rm *.log *.txt *.json *.v *.dot *.png

schematic:
	yosys -m slang -ql synth_log.txt -p "read_slang -v $(SOURCE_FILES); synth_gatemate -top $(TOP); show -format png -prefix schematic"