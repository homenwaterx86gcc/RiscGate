
IBEX_FILES := ibex_pkg.sv ibex_alu.sv ibex_compressed_decoder.sv ibex_csr.sv ibex_controller.sv \
					ibex_counter.sv ibex_cs_registers.sv ibex_decoder.sv ibex_ex_block.sv ibex_wb_stage.sv \
					ibex_id_stage.sv ibex_if_stage.sv ibex_load_store_unit.sv ibex_multdiv_slow.sv \
					ibex_multdiv_fast.sv ibex_prefetch_buffer.sv ibex_fetch_fifo.sv ibex_register_file_ff.sv \
					ibex_core.sv prim_ram_1p_pkg.sv ibex_core.sv ibex_top.sv

DEMO_SYSTEM_FILES := uart.sv gatemate_ram2p.sv bus.sv prim_count_pkg.sv prim_count.sv prim_fifo_sync_cnt.sv \
					prim_fifo_sync.sv prim_flop.sv prim_util_pkg.sv ibex_demo_system.sv

SOURCE_FILES := $(addprefix rtl/, $(IBEX_FILES) $(DEMO_SYSTEM_FILES))
TOP = ibex_demo_system

synthesize:
	yosys -m slang -ql synth_log.txt -p "read_slang -v $(SOURCE_FILES); synth_gatemate -top $(TOP) -luttree -nomx8; write_verilog $(TOP)_netlist.v; write_json $(TOP).json"

clean:
	rm *.log *.txt *.json *.v *.dot *.png

schematic:
	yosys -m slang -ql synth_log.txt -p "read_slang -v $(SOURCE_FILES); synth_gatemate -top $(TOP); show -format png -prefix schematic"

bram:
	yosys -m slang -ql synth_log.txt -p "read_slang rtl/gatemate_ram2p.sv; hierarchy -check -top gatemate_ram2p; synth_gatemate -luttree -nomx8; write_verilog gatemate_ram2p_netlist.v; write_json gatemate_ram2p.json"