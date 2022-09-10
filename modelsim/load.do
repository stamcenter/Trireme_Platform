#####################################################
# Create Modelsim library and compile design files. #
#####################################################

# Create a library for working in
vlib work

set rtl ../rtl
set compile_arg +define+INCLUDE_FILE="$rtl/includes/params.h"

# Common source and tests
set common_v_dir  $rtl/common/src
set common_tb_dir $rtl/common/tb

vlog -quiet $compile_arg $common_v_dir/*.v
vlog -quiet $compile_arg $common_tb_dir/*.v

# Core source and tests
set core_base_v_dir     $rtl/cores/base/src
set core_base_tb_dir    $rtl/cores/base/tb
set five_stage_v_dir   $rtl/cores/five_stage/src
set five_stage_tb_dir  $rtl/cores/five_stage/tb
set seven_stage_v_dir   $rtl/cores/seven_stage/src
set seven_stage_tb_dir  $rtl/cores/seven_stage/tb
set single_cycle_v_dir  $rtl/cores/single_cycle/src
set single_cycle_tb_dir $rtl/cores/single_cycle/tb

vlog -quiet $compile_arg $core_base_v_dir/*.v
vlog -quiet $compile_arg $core_base_tb_dir/*.v
vlog -quiet $compile_arg $five_stage_v_dir/*.v
vlog -quiet $compile_arg $five_stage_tb_dir/*.v
vlog -quiet $compile_arg $seven_stage_v_dir/*.v
vlog -quiet $compile_arg $seven_stage_tb_dir/*.v
vlog -quiet $compile_arg $single_cycle_v_dir/*.v
vlog -quiet $compile_arg $single_cycle_tb_dir/*.v


# Memory source and tests
set memory_base_v_dir            $rtl/memory/base/src
set memory_base_tb_dir           $rtl/memory/base/tb
set dual_port_BRAM_memory_v_dir  $rtl/memory/dual_port_BRAM_memory/src
set dual_port_BRAM_memory_tb_dir $rtl/memory/dual_port_BRAM_memory/tb
set main_memory_v_dir            $rtl/memory/main_memory/src
set main_memory_tb_dir           $rtl/memory/main_memory/tb
set single_cycle_memory_v_dir    $rtl/memory/single_cycle_memory/src
set single_cycle_memory_tb_dir   $rtl/memory/single_cycle_memory/tb
set cache_base_v_dir             $rtl/memory/cache_subsystem/base/src
set cache_base_tb_dir            $rtl/memory/cache_subsystem/base/tb
set cache_l1_v_dir               $rtl/memory/cache_subsystem/L1cache/src
set cache_l1_tb_dir              $rtl/memory/cache_subsystem/L1cache/tb
set cache_lx_v_dir               $rtl/memory/cache_subsystem/Lxcache/src
set cache_lx_tb_dir              $rtl/memory/cache_subsystem/Lxcache/tb
set cache_wrappers_v_dir         $rtl/memory/cache_subsystem/hierarchies/src
set cache_wrappers_tb_dir        $rtl/memory/cache_subsystem/hierarchies/tb

vlog -quiet $compile_arg $memory_base_v_dir/*.v
vlog -quiet $compile_arg $memory_base_tb_dir/*.v
vlog -quiet $compile_arg $dual_port_BRAM_memory_v_dir/*.v
vlog -quiet $compile_arg $dual_port_BRAM_memory_tb_dir/*.v
vlog -quiet $compile_arg $main_memory_v_dir/*.v
vlog -quiet $compile_arg $main_memory_tb_dir/*.v
vlog -quiet $compile_arg $single_cycle_memory_v_dir/*.v
vlog -quiet $compile_arg $single_cycle_memory_tb_dir/*.v
vlog -quiet $compile_arg $cache_base_v_dir/*.v
vlog -quiet $compile_arg $cache_base_tb_dir/*.v
vlog -quiet $compile_arg $cache_l1_v_dir/*.v
vlog -quiet $compile_arg $cache_l1_tb_dir/*.v
vlog -quiet $compile_arg $cache_lx_v_dir/*.v
vlog -quiet $compile_arg $cache_lx_tb_dir/*.v
vlog -quiet $compile_arg $cache_wrappers_v_dir/*.v
vlog -quiet $compile_arg $cache_wrappers_tb_dir/*.v

# IO source and tests
set io_uart_v_dir  $rtl/io/uart/src
set io_uart_tb_dir $rtl/io/uart/tb
set io_reg_v_dir   $rtl/io/register/src
set io_reg_tb_dir  $rtl/io/register/tb
set io_timer_v_dir   $rtl/io/timer/src
set io_timer_tb_dir  $rtl/io/timer/tb

vlog -quiet $compile_arg $io_uart_v_dir/*.v
vlog -quiet $compile_arg $io_uart_tb_dir/*.v
vlog -quiet $compile_arg $io_reg_v_dir/*.v
vlog -quiet $compile_arg $io_reg_tb_dir/*.v
vlog -quiet $compile_arg $io_timer_v_dir/*.v
vlog -quiet $compile_arg $io_timer_tb_dir/*.v

# Top source and tests
set tops_v_dir  $rtl/tops/src
set tops_tb_dir $rtl/tops/tb

vlog -quiet $compile_arg $tops_v_dir/*.v
vlog -quiet $compile_arg $tops_tb_dir/*.v

quit
